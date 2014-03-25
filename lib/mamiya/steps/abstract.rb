require 'mamiya/config'
require 'mamiya/script'
require 'mamiya/logger'

module Mamiya
  module Steps
    class Abstract
      def initialize(script: Mamiya::Script.new, config: Mamiya::Config.new, logger: Mamiya::Logger.new, **options)
        @script, @config, @logger, @options = script, config, logger[self.class.name], options
      end

      attr_reader :script, :config, :options, :logger

      def run!
      end
    end
  end
end
