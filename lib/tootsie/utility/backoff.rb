module Tootsie
  module Utility

    class Backoff

      def initialize(options = {})
        @min = options[:min] || 0.5
        @max = options[:max] || 2.0
        @current = options[:initial] || @min
        @factor = options[:factor] || 1.5
      end

      def with(&block)
        loop do
          result = yield
          if result
            @current /= @factor
            return result
          else
            @current = [[@current * @factor, @min].max, @max].min
            sleep(@current) if @current > 0
          end
        end
      end

    end

  end
end