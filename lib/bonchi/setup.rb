require "fileutils"
require "shellwords"

module Bonchi
  class Setup
    include Colors

    def initialize(worktree: nil)
      @worktree = worktree || Dir.pwd
      @main_worktree = Git.main_worktree
    end

    def run(args = [])
      if @worktree == @main_worktree
        abort "#{color(:red)}Error:#{reset} already in the main worktree"
      end

      config = Config.from_main_worktree
      abort "#{color(:red)}Error:#{reset} .worktree.yml not found in main worktree" unless config

      ENV["WORKTREE_MAIN"] = @main_worktree
      ENV["WORKTREE_LINKED"] = @worktree
      ENV["WORKTREE_BRANCH"] = Git.current_branch(@worktree)
      ENV["WORKTREE_BRANCH_SLUG"] = ENV["WORKTREE_BRANCH"].gsub(/[^a-zA-Z0-9_]/, "_")
      ENV["WORKTREE_ROOT"] ||= GlobalConfig.new.worktree_root

      puts "Setting up worktree from: #{@main_worktree}"

      copy_files(config.copy)
      link_files(config.link)

      # Prefer linked worktree's .worktree.yml if it was copied or already exists
      linked_config = Config.from_worktree(@worktree)
      if linked_config
        puts "Using .worktree.yml from linked worktree"
        config = linked_config
      end

      allocate_ports(config.ports) if config.ports.any?
      replace_in_files(config.replace) if config.replace.any?
      run_pre_setup(config.pre_setup)
      exec_setup(config.setup, args)
    end

    private

    def allocate_ports(port_names)
      pool = PortPool.new
      ports = pool.allocate(@worktree, port_names)
      ports.each { |name, port| ENV[name] = port.to_s }
    end

    def link_files(files)
      files.each do |file|
        src = File.join(@main_worktree, file)
        dest = File.join(@worktree, file)

        unless File.exist?(src)
          puts "#{color(:yellow)}Warning:#{reset} #{file} not found in main worktree, skipping"
          next
        end

        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.rm_rf(dest) if File.exist?(dest) || File.symlink?(dest)
        FileUtils.ln_s(src, dest)
        puts "Linked #{file} -> #{src}"
      end
    end

    def copy_files(files)
      files.each do |file|
        src = File.join(@main_worktree, file)
        dest = File.join(@worktree, file)
        if File.exist?(src)
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(src, dest)
          puts "Copied #{file}"
        else
          puts "#{color(:yellow)}Warning:#{reset} #{file} not found in main worktree, skipping"
        end
      end
    end

    def replace_in_files(replacements)
      replacements.each do |file, entries|
        path = File.join(@worktree, file)
        abort "#{color(:red)}Error:#{reset} #{file} not found" unless File.exist?(path)

        content = File.read(path)
        entries.each do |entry|
          if entry.is_a?(Hash) && entry.key?("match")
            pattern = entry["match"]
            replacement = entry["with"]
            missing = entry["missing"] || "halt"
          elsif entry.is_a?(Hash)
            pattern, replacement = entry.first
            missing = "halt"
          else
            abort "#{color(:red)}Error:#{reset} invalid replace entry in #{file}: #{entry.inspect}"
          end

          expanded = replacement.gsub(/\$(\w+)/) { ENV[$1] || abort("#{color(:red)}Error:#{reset} $#{$1} not set") }
          regex = Regexp.new(pattern)

          unless content.match?(regex)
            if missing == "warn"
              puts "#{color(:yellow)}Warning:#{reset} pattern #{pattern} not found in #{file}, skipping"
              next
            else
              abort "#{color(:red)}Error:#{reset} pattern #{pattern} not found in #{file}"
            end
          end

          content = content.gsub(regex, expanded)
          puts "Replaced #{pattern} in #{file}"
        end
        File.write(path, content)
      end
    end

    def run_pre_setup(commands)
      commands.each do |cmd|
        puts "Running: #{cmd}"
        Dir.chdir(@worktree) do
          system(cmd) || abort("Command failed: #{cmd}")
        end
      end
    end

    def exec_setup(setup_cmd, args)
      puts "\n== Running #{setup_cmd} =="
      Dir.chdir(@worktree) do
        exec(*setup_cmd.shellsplit, *args)
      end
    end
  end
end
