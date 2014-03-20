require 'mamiya/steps/abstract'
require 'mamiya/package'

module Mamiya
  module Steps
    class Push < Abstract
      def run!
        package = case options[:package]
                  when Mamiya::Package
                    options[:package]
                  else
                    Mamiya::Package.new(options[:package])
                  end

        application = options[:application] || package.application

        raise 'no application name given' unless application

        storage = config.storage_class.new(
          config[:storage].merge(
            application: application
          )
        )

        storage.push(package)
      end
    end
  end
end

