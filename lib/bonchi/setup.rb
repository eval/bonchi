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
