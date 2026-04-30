require "fileutils"
require "shellwords"

module Bonchi
  class Setup
    include Colors

    def initialize(worktree: nil)
      @worktree = worktree || Dir.pwd
      @main_worktree = Git.main_worktree
    end

    STEPS = %w[copy link ports replace pre_setup setup].freeze

    def run(args = [], upto: nil)
      if upto && !STEPS.include?(upto)
        abort "#{color(:red)}Error:#{reset} unknown step '#{upto}'. Valid steps: #{STEPS.join(", ")}"
      end

      if @worktree == @main_worktree
        abort "#{color(:red)}Error:#{reset} already in the main worktree"
      end

      config = Config.from_worktree(@worktree)
      if config
        puts "Using .worktree.yml from linked worktree"
      else
        config = Config.from_main_worktree
        abort "#{color(:red)}Error:#{reset} .worktree.yml not found in main worktree" unless config
      end

      last_step = upto || STEPS.last
      run_steps = STEPS[0..STEPS.index(last_step)]

      ENV["WORKTREE_MAIN"] = @main_worktree
      ENV["WORKTREE_LINKED"] = @worktree
      ENV["WORKTREE_BRANCH"] = Git.current_branch(@worktree)
      ENV["WORKTREE_BRANCH_SLUG"] = ENV["WORKTREE_BRANCH"].gsub(/[^a-zA-Z0-9_]/, "_")
      ENV["WORKTREE_ROOT"] ||= GlobalConfig.new.worktree_root

      puts "Setting up worktree from: #{@main_worktree}"

      copy_files(config.copy) if run_steps.include?("copy")
      link_files(config.link) if run_steps.include?("link")
      allocate_ports(config.ports) if run_steps.include?("ports") && config.ports.any?
      replace_in_files(config.replace) if run_steps.include?("replace") && config.replace.any?
      run_pre_setup(config.pre_setup) if run_steps.include?("pre_setup")
      exec_setup(config.setup, args) if run_steps.include?("setup")
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
        entries.each { |entry| content = apply_edit(entry, content, file) }
        File.write(path, content)
      end
    end

    def apply_edit(entry, content, file)
      unless entry.is_a?(Hash)
        abort "#{color(:red)}Error:#{reset} invalid edit entry in #{file}: #{entry.inspect}"
      end

      if entry.key?("append")
        line = expand(entry["append"])
        puts "Appended to #{file}"
        ensure_trailing_newline(content) + line + "\n"
      elsif entry.key?("upsert")
        unless entry.key?("with")
          abort "#{color(:red)}Error:#{reset} 'upsert' requires 'with' in #{file}"
        end
        pattern = entry["upsert"]
        replacement = expand(entry["with"])
        regex = Regexp.new(pattern)
        if content.match?(regex)
          puts "Upserted #{pattern} in #{file} (matched)"
          content.gsub(regex, replacement)
        else
          puts "Upserted #{pattern} in #{file} (appended)"
          ensure_trailing_newline(content) + replacement + "\n"
        end
      elsif entry.key?("match")
        replace(content, entry["match"], expand(entry["with"]), entry["missing"] || "halt", file)
      else
        pattern, replacement = entry.first
        replace(content, pattern, expand(replacement), "halt", file)
      end
    end

    def replace(content, pattern, replacement, missing, file)
      regex = Regexp.new(pattern)
      unless content.match?(regex)
        if missing == "warn"
          puts "#{color(:yellow)}Warning:#{reset} pattern #{pattern} not found in #{file}, skipping"
          return content
        else
          abort "#{color(:red)}Error:#{reset} pattern #{pattern} not found in #{file}"
        end
      end
      puts "Replaced #{pattern} in #{file}"
      content.gsub(regex, replacement)
    end

    def expand(value)
      value.to_s.gsub(/\$(\w+)/) { ENV[$1] || abort("#{color(:red)}Error:#{reset} $#{$1} not set") }
    end

    def ensure_trailing_newline(content)
      content.empty? || content.end_with?("\n") ? content : content + "\n"
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
