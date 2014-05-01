require 'mamiya/package'
require 'mamiya/storages/abstract'
require 'fileutils'

module Mamiya
  module Storages
    class Mock < Mamiya::Storages::Abstract
      def self.storage
        @storage ||= {}
      end

      def self.clear
        @storage = {}
      end

      def self.find(config={})
        storage.keys
      end

      def initialize(*)
        super
        self.class.storage[application] ||= {}
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

      def fetch(package_name, destination)
        self.class.storage[application] ||= {}
        raise NotFound unless self.class.storage[application][package_name]
        package_path = File.join(destination, "#{package_name}.tar.gz")
        meta_path = File.join(destination, "#{package_name}.json")

        if File.exists?(package_path) || File.exists?(meta_path)
          raise AlreadyFetched
        end

        package = self.class.storage[application][package_name][:package]
        FileUtils.cp package.path, package_path
        FileUtils.cp package.meta_path, meta_path
        return package
      end

      def meta(package_name)
        package = self.class.storage[application][package_name]
        return unless package

        package[:package].meta
      end
    end
  end
end
