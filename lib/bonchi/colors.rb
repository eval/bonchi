module Bonchi
  module Colors
    private

    def color(name)
      return "" if ENV.key?("NO_COLOR")

      case name
      when :red then "\e[31m"
      when :yellow then "\e[33m"
      end
    end

    def reset
      return "" if ENV.key?("NO_COLOR")

      "\e[0m"
    end
  end
end
