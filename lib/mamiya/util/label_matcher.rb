module Mamiya
  module Util
    module LabelMatcher
      def match?(*expressions)
        labels = self.labels()

        if expressions.all? { |_| _.kind_of?(Symbol) || _.kind_of?(String) }
          return self.match?(expressions)
        end

        expressions.any? do |expression|
          case expression
          when Symbol, String
            labels.include?(expression)
          when Array
            if expression.any? { |_| _.kind_of?(Array) }
              self.match?(*expression)
            else
              expression.all? { |_| labels.include?(_) }
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
