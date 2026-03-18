module Bonchi
  module Colors
    private

    def color(name)
      return "" if ENV.key?("NO_COLOR") || !$stdout.tty?

      case name
      when :red then "\e[31m"
      when :green then "\e[32m"
      when :yellow then "\e[33m"
      when :dim then "\e[2m"
      end
    end

    def reset
      return "" if ENV.key?("NO_COLOR") || !$stdout.tty?

      "\e[0m"
    end
  end
end
