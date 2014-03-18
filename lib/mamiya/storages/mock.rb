require 'mamiya/package'
require 'mamiya/storages/abstract'

module Mamiya
  module Storages
    class Mock < Mamiya::Storages::Abstract
      def self.storage
        @storage ||= {}
      end

      def self.find(config={})
        storage.keys
      end

      def packages
        self.class.storage[application].keys
      end

      def push(package)
        raise TypeError, "package should be a kind of Mamiya::Package" unless package.kind_of?(Mamiya::Package)
        raise NotBuilt, "package not built" unless package.exists?
        self.class.storage[application] ||= {}
        raise AlreadyExists if self.class.storage[application][package.name]
        self.class.storage[application][package.name] = {package: package, config: config}
      end
    end
  end
end
