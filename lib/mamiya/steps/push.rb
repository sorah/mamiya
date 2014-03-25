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

        logger.info "Pushing #{package.path} to storage(app=#{storage.application})..."

        storage.push(package)

        logger.info "DONE!"
      end
    end
  end
end

