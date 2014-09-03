require 'mamiya/script'
require 'mamiya/logger'
require 'mamiya/configuration'

module Mamiya
  module Steps
    class Abstract
      def initialize(script: Mamiya::Script.new, config: Mamiya::Configuration.new, logger: Mamiya::Logger.new, **options)
        @script, @config, @options = script, config, options
        @logger = logger[self.class.name.sub(/^Mamiya::Steps::/,'')]
      end

      attr_reader :script, :config, :options, :logger

      def run!
      end
    end
  end
end
