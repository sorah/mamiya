require 'mamiya/steps/abstract'
require 'mamiya/package'

module Mamiya
  module Steps
    class Fetch < Abstract
      def run!
        application = options[:application] || (script && script.application)

        raise 'no application name given' unless application

        storage = config.storage_class.new(
          config[:storage].merge(
            application: application
          )
        )

        storage.fetch(options[:package], options[:destination])
      end
    end
  end
end

