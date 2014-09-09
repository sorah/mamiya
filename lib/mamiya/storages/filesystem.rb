require 'mamiya/package'
require 'mamiya/storages/abstract'
require 'fileutils'

module Mamiya
  module Storages
    class Filesystem < Mamiya::Storages::Abstract
      def self.find(config={})
        Hash[Dir[File.join(config[:path], '*')].map do |app_path|
          app = File.basename(app_path)
          [app, self.new(config.merge(application: app))]
        end]
      end

      def packages
        storage_path.children(false).group_by { |child|
          child.to_s.sub(Package::PATH_SUFFIXES,'')
        }.select { |key, files|
          files.find { |file| file.to_s.end_with?('.tar.gz') } &&
          files.find { |file| file.to_s.end_with?('.json') }
        }.keys.sort
      end

      def push(package)
        raise TypeError, "package should be a kind of Mamiya::Package" unless package.kind_of?(Mamiya::Package)
        raise NotBuilt, "package not built" unless package.exists?

        if package_exist?(package.name)
          raise AlreadyExists 
        end

        storage_path.mkpath

        FileUtils.cp package.path, storage_path.join("#{package.name}.tar.gz")
        FileUtils.cp package.meta_path, storage_path.join("#{package.name}.json")
      end

      def fetch(package_name, destination)
        package_name = normalize_package_name(package_name)
        raise NotFound unless package_exist?(package_name)

        package_path = File.join(destination, "#{package_name}.tar.gz")
        meta_path = File.join(destination, "#{package_name}.json")

        if File.exists?(package_path) || File.exists?(meta_path)
          raise AlreadyFetched
        end

        FileUtils.cp storage_path.join("#{package_name}.tar.gz"), package_path
        FileUtils.cp storage_path.join("#{package_name}.json"), meta_path
        
        return Mamiya::Package.new(package_path)
      end

      def meta(package_name)
        package_name = normalize_package_name(package_name)
        return unless package_exist?(package_name)

        JSON.parse storage_path.join("#{package_name}.json").read
      end

      def remove(package_name)
        package_name = normalize_package_name(package_name)

        package_path = storage_path.join("#{package_name}.tar.gz")
        meta_path = storage_path.join("#{package_name}.json")

        if [package_path, meta_path].all? { |_| !_.exist? }
          raise Mamiya::Storages::Abstract::NotFound
        end

        package_path.delete if package_path.exist?
        meta_path.delete if meta_path.exist?
      end

      private

      def storage_path
        @storage_path ||= Pathname.new(@config[:path]).join(@config[:application])
      end

      def package_exist?(name)
        storage_path.join("#{name}.tar.gz").exist? &&
          storage_path.join("#{name}.json").exist?
      end

      def normalize_package_name(name)
        name.sub(/\.(?:tar\.gz|json)\z/, '')
      end
    end
  end
end
