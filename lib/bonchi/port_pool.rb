require "set"
require "yaml"
require "socket"

module Bonchi
  class PortPool
    DEFAULT_MIN = 4000
    DEFAULT_MAX = 5000

    # Ports browsers refuse to connect to (Chrome: ERR_UNSAFE_PORT, Firefox: a
    # similar block). Allocating one of these for a dev web server makes it
    # unreachable in the browser even though the server binds fine. This is
    # Chromium's kRestrictedPorts list (net/base/port_util.cc); ports outside
    # the pool range are harmless to keep listed. 4045 (lockd) and 4190 (sieve)
    # fall inside the default 4000..5000 range.
    UNSAFE_PORTS = [
      1, 7, 9, 11, 13, 15, 17, 19, 20, 21, 22, 23, 25, 37, 42, 43, 53, 69, 77,
      79, 87, 95, 101, 102, 103, 104, 109, 110, 111, 113, 115, 117, 119, 123,
      135, 137, 139, 143, 161, 179, 389, 427, 465, 512, 513, 514, 515, 526,
      530, 531, 532, 540, 548, 554, 556, 563, 587, 601, 636, 989, 990, 993,
      995, 1719, 1720, 1723, 2049, 3659, 4045, 4190, 5060, 5061, 6000, 6566,
      6665, 6666, 6667, 6668, 6669, 6697, 10080
    ].to_set.freeze

    def initialize
      @path = GlobalConfig.config_path
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
          port = (@min..@max).find { |p| !used.include?(p) && !UNSAFE_PORTS.include?(p) && port_available?(p) }
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

    def load_config
      data = if File.exist?(@path)
        YAML.safe_load_file(@path) || {}
      else
        {}
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
