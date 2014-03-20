require 'mamiya/steps/abstract'
require 'mamiya/package'

module Mamiya
  module Steps
    class Push < Abstract
      def run!
        package = Mamiya::Package.new(options[:target_package])
        storage = config.storage_class.new(config[:storage].merge(application: script.application))
        storage.push(package)
      end
    end
  end
end

