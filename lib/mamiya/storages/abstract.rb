module Mamiya
  module Storages
    class Abstract
      class NotBuilt < Exception; end
      class NotFound < Exception; end
      class AlreadyExists < Exception; end
      class AlreadyFetched < Exception; end

      def initialize(config = {})
        @config = config.dup
        @application = config.delete(:application)
      end

      attr_reader :config, :application

      def self.find(config={})
        {}
      end

      def packages
        []
      end

      def push(package)
        raise NotImplementedError
      end

      def fetch(package_name, dir)
        raise NotImplementedError
      end

      def meta(package_name)
        raise NotImplementedError
      end

      def remove(package)
        raise NotImplementedError
      end

      def prune(nums_to_keep)
        packages = self.packages()
        (packages - packages.last(nums_to_keep)).each do |package|
          self.remove(package)
        end
      end
    end
  end
end
