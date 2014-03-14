require 'mamiya/package'
require 'mamiya/storages/abstract'
require 'aws-sdk-core'
require 'json'

module Mamiya
  module Storages
    class S3 < Mamiya::Storages::Abstract
      def applications
        Hash[s3.list_objects(bucket: @config[:bucket], delimiter: '/').common_prefixes.map { |prefix|
          app = prefix.prefix.gsub(%r{/$},'')
          [app, self.class.new(@config.merge(application: app))]
        }]
      end

      def packages
        s3.list_objects(bucket: @config[:bucket], delimiter: '/', prefix: "#{self.application}/").contents.map { |content|
          content.key.sub(/\A#{Regexp.escape(self.application)}\//, '')
        }.group_by { |key|
          key.sub(/(?:\.tar\.gz|\.json)\z/,'')
        }.select { |key, files|
          files.find { |file| file.end_with?('.tar.gz') } && files.find { |file| file.end_with?('.json') }
        }.keys
      end

      def push(package)
        raise TypeError, "package should be a kind of Mamiya::Package" unless package.kind_of?(Mamiya::Package)
        raise NotBuilt, "package not built" unless package.exists?

        package_key, meta_key = package_and_meta_key_for(package.name)

        [package_key, meta_key].each do |key|
          raise AlreadyExists if key_exists_in_s3?(key)
        end

        open(package.path, 'rb') do |io|
          s3.put_object(bucket: @config[:bucket], key: package_key, body: io)
        end
        open(package.meta_path, 'rb') do |io|
          s3.put_object(bucket: @config[:bucket], key: meta_key, body: io)
        end
      end

      def fetch(package_name, dir)
        package_key, meta_key = package_and_meta_key_for(package_name)

        package_path = File.join(dir, "#{package_name}.tar.gz")
        meta_path = File.join(dir, "#{package_name}.json")

        if File.exists?(package_path) || File.exists?(meta_path)
          raise AlreadyFetched
        end

        open(package_path, 'wb+') do |io|
          s3.get_object({bucket: @config[:bucket], key: package_key}, target: io)
        end
        open(meta_path, 'wb+') do |io|
          s3.get_object({bucket: @config[:bucket], key: meta_key}, target: io)
        end

        return Mamiya::Package.new(package_path)
      rescue Aws::S3::Errors::NoSuchKey
        File.unlink package_path if package_path && File.exists?(package_path)
        File.unlink meta_path if meta_path && File.exists?(meta_path)
        raise NotFound
      end

      def meta(package_name)
        _, meta_key = package_and_meta_key_for(package_name)
        JSON.parse(s3.get_object(bucket: @config[:bucket], key: meta_key).body.string)
      rescue Aws::S3::Errors::NoSuchKey
        return nil
      end

      def remove(package_name)
        package_key, meta_key = package_and_meta_key_for(package_name)

        objs_to_delete = [package_key, meta_key].map { |key|
          if key_exists_in_s3?(key)
            {key: key}
          else
            nil
          end
        }.compact
        raise NotFound if objs_to_delete.empty?

        s3.delete_objects(bucket: @config[:bucket], objects: objs_to_delete)
      end

      private

      def s3
        return @s3 if @s3
        s3_config = @config.dup
        s3_config.delete(:bucket)
        s3_config.delete(:application)
        @s3 = Aws::S3.new(s3_config)
      end

      def package_and_meta_key_for(package_name)
        ["#{self.application}/#{package_name}.tar.gz", "#{self.application}/#{package_name}.json"]
      end

      def key_exists_in_s3?(key)
        begin
          if s3.head_object(bucket: @config[:bucket], key: key)
            true
          end
        rescue Aws::S3::Errors::NotFound
          false
        end
      end
    end
  end
end
