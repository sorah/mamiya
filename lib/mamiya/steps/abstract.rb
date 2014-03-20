require 'mamiya/config'
require 'mamiya/script'

module Mamiya
  module Steps
    class Abstract
      def initialize(script = Mamiya::Script.new, config = Mamiya::Config.new, options = {})
        @script, @config, @options = script, config, options
      end

      attr_reader :script, :config, :options

      def run!
      end
    end
  end
end
