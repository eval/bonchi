require "yaml"

module Bonchi
  class Config
    include Colors

    KNOWN_KEYS = %w[copy link ports replace pre_setup setup].freeze

    attr_reader :copy, :link, :ports, :replace, :pre_setup, :setup

    def initialize(path)
      data = YAML.load_file(path)

      unknown = data.keys - KNOWN_KEYS
      unknown.each { |k| warn "#{color(:yellow)}Warning:#{reset} unknown key '#{k}' in .worktree.yml, ignoring" }

      @copy = Array(data["copy"])
      @link = Array(data["link"])
      @ports = Array(data["ports"])
      @replace = data["replace"] || {}
      @pre_setup = Array(data["pre_setup"])
      @setup = data["setup"] || "bin/setup"

      validate!
    end

    def self.from_main_worktree
      from_worktree(Git.main_worktree)
    end

    def self.from_worktree(dir)
      path = File.join(dir, ".worktree.yml")
      return nil unless File.exist?(path)

      new(path)
    end

    private

    def validate!
      unless @replace.is_a?(Hash)
        abort "#{color(:red)}Error:#{reset} 'replace' must be a mapping of filename to list of replacements"
      end

      @replace.each do |file, entries|
        unless entries.is_a?(Array)
          abort "#{color(:red)}Error:#{reset} 'replace.#{file}' must be a list of replacements"
        end

        entries.each do |entry|
          unless entry.is_a?(Hash)
            abort "#{color(:red)}Error:#{reset} each replacement in 'replace.#{file}' must be a mapping"
          end
        end
      end

      unless @setup.is_a?(String)
        abort "#{color(:red)}Error:#{reset} 'setup' must be a string"
      end
    end
  end
end
