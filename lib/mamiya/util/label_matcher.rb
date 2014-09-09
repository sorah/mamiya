module Mamiya
  module Util
    module LabelMatcher
      def self.parse_string_expr(str)
        str.split(/\|/).map{ |_| _.split(/,/) }
      end

      def match?(*expressions)
        labels = self.labels().map(&:to_s)

        if expressions.all? { |_| _.kind_of?(Symbol) || _.kind_of?(String) }
          return self.match?(expressions)
        end

        expressions.any? do |expression|
          case expression
          when Symbol, String
            labels.include?(expression.to_s)
          when Array
            if expression.any? { |_| _.kind_of?(Array) }
              self.match?(*expression)
            else
              expression.all? { |_| labels.include?(_.to_s) }
            end
          end
        end
      end

      alias matches? match?

      class Simple
        def initialize(*labels)
          @labels = labels.flatten
        end

        attr_reader :labels

        include LabelMatcher
      end
    end
  end
end
