require "yaml"
require "fileutils"

module Bonchi
  class GlobalConfig
    def initialize
      @path = self.class.config_path
      @data = if File.exist?(@path)
        YAML.safe_load_file(@path) || {}
      else
        {}
      end
    end

    attr_reader :path, :data

    def worktree_root
      ENV.fetch("WORKTREE_ROOT") {
        @data["worktree_root"] || File.join(Dir.home, "dev", "worktrees")
      }
    end

    def self.config_path
      xdg = ENV["XDG_CONFIG_HOME"]
      if xdg && !xdg.empty?
        dir = File.join(xdg, "bonchi")
        FileUtils.mkdir_p(dir)
        File.join(dir, "config.yml")
      else
        File.expand_path("~/.bonchi.yml")
      end
    end
  end
end
