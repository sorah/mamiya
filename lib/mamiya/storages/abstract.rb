module Mamiya
  module Storages
    class Abstract
      def initialize(config = {})
      end

      def applications
      end

      def packages
      end

      def push(package)
      end

      def fetch(package_name)
      end

      def remove(package)
      end

      def prune
        # TODO: remove old packages
      end
    end
  end
end
