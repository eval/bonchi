require "yaml"

module Bonchi
  class Config
    attr_reader :copy, :ports, :pre_setup, :setup

    def initialize(path)
      data = YAML.load_file(path)
      @copy = Array(data["copy"])
      @ports = Array(data["ports"])
      @pre_setup = Array(data["pre_setup"])
      @setup = data["setup"] || "bin/setup"
    end

    def self.from_main_worktree
      main = Git.main_worktree
      path = File.join(main, ".worktree.yml")
      return nil unless File.exist?(path)

      new(path)
    end
  end
end
