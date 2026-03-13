require "fileutils"
require "shellwords"

module Bonchi
  class Setup
    def initialize(worktree: nil)
      @worktree = worktree || Dir.pwd
      @main_worktree = Git.main_worktree
    end

    def run(args = [])
      if @worktree == @main_worktree
        abort "Error: already in the main worktree"
      end

      config = Config.from_main_worktree
      abort "Error: .worktree.yml not found in main worktree" unless config

      ENV["MAIN_WORKTREE"] = @main_worktree
      ENV["WORKTREE"] = @worktree

      puts "Setting up worktree from: #{@main_worktree}"

      allocate_ports(config.ports) if config.ports.any?
      copy_files(config.copy)
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

    def copy_files(files)
      files.each do |file|
        src = File.join(@main_worktree, file)
        if File.exist?(src)
          FileUtils.cp(src, File.join(@worktree, file))
          puts "Copied #{file}"
        else
          puts "Warning: #{file} not found in main worktree, skipping"
        end
      end
    end

    def replace_in_files(replacements)
      replacements.each do |file, entries|
        path = File.join(@worktree, file)
        abort "Error: #{file} not found" unless File.exist?(path)

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
            abort "Error: invalid replace entry in #{file}: #{entry.inspect}"
          end

          expanded = replacement.gsub(/\$(\w+)/) { ENV[$1] || abort("Error: $#{$1} not set") }
          regex = Regexp.new(pattern)

          unless content.match?(regex)
            if missing == "warn"
              puts "Warning: pattern #{pattern} not found in #{file}, skipping"
              next
            else
              abort "Error: pattern #{pattern} not found in #{file}"
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
