require 'mamiya/config'
require 'mamiya/script'

module Mamiya
  module Steps
    class Abstract
      def initialize(script = Mamiya::Script.new, config = Mamiya::Config.new)
        @script, @config = script, config
      end

      attr_reader :script, :config

      def run!
      end
    end
  end
end
