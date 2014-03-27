require 'mamiya/steps/abstract'


module Mamiya
  module Steps
    class Extract < Abstract
      def run!
        package = case options[:package]
                  when Mamiya::Package
                    options[:package]
                  else
                    Mamiya::Package.new(options[:package])
                  end

        if File.exists?(options[:destination])
          destination = File.join(options[:destination], package.name)
        else
          destination = options[:destination]
        end

        logger.info "Extracting #{package.path} onto #{destination}"
        package.extract_onto!(destination)
      end
    end
  end
end
