require "yaml"
require "socket"
require "set"

module Bonchi
  class PortPool
    DEFAULT_MIN = 4000
    DEFAULT_MAX = 5000

    def initialize
      @path = global_config_path
      load_config
    end

    def allocate(worktree_path, port_names)
      prune_stale

      existing = @allocated[worktree_path] || {}
      if port_names.all? { |name| existing[name] }
        port_names.each_with_object({}) do |name, result|
          result[name] = existing[name]
          puts "Reusing port #{existing[name]} for #{name}"
        end
      else
        used = @allocated.reject { |k, _| k == worktree_path }
          .values.flat_map { |ports| ports.values }.to_set

        new_ports = {}
        port_names.each do |name|
          port = (@min..@max).find { |p| !used.include?(p) && port_available?(p) }
          abort "Error: no available port for #{name}" unless port
          used << port
          new_ports[name] = port
          puts "Allocated port #{port} for #{name}"
        end

        @allocated[worktree_path] = new_ports
        save_config
        new_ports
      end
    end

    private

    def global_config_path
      xdg = ENV["XDG_CONFIG_HOME"]
      if xdg && !xdg.empty?
        dir = File.join(xdg, "bonchi")
        FileUtils.mkdir_p(dir)
        File.join(dir, "config.yml")
      else
        File.expand_path("~/.bonchi.yml")
      end
    end

    def load_config
      if File.exist?(@path)
        data = YAML.safe_load_file(@path) || {}
      else
        data = {}
      end
      pool = data["port_pool"] || {}
      @min = pool["min"] || DEFAULT_MIN
      @max = pool["max"] || DEFAULT_MAX
      @allocated = pool["allocated"] || {}
    end

    def save_config
      data = {
        "port_pool" => {
          "min" => @min,
          "max" => @max,
          "allocated" => @allocated
        }
      }
      File.write(@path, YAML.dump(data))
    end

    def prune_stale
      @allocated.delete_if { |path, _| !File.directory?(path) }
    end

    def port_available?(port)
      server = TCPServer.new("127.0.0.1", port)
      server.close
      true
    rescue Errno::EADDRINUSE
      false
    end
  end
end
