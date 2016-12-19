require 'mamiya/package'
require 'mamiya/storages/s3'
require 'fileutils'

module Mamiya
  module Storages
    # Because there's no S3 endpoint in Amazon VPC, fetching from instances
    # with no public IP may consume your NAT instances' bandwidth. This
    # basically uses Amazon S3 but use s3_proxy.gem for fetching from specific
    # host to avoid heavy bandwidth load.
    #
    # Note: s3_proxy is a simple Rack app that proxies HTTP GET requests to
    # Amazon S3 GetObject.  You can use it with puma + nginx proxy_cache
    # to avoid heavy bandwidth load.
    class S3Proxy < Mamiya::Storages::S3
      def fetch(package_name, dir)
        package_key, meta_key = package_and_meta_key_for(package_name)

        package_path = File.join(dir, File.basename(package_key))
        meta_path = File.join(dir, File.basename(meta_key))

        if File.exists?(package_path) && File.exists?(meta_path)
          raise AlreadyFetched
        end

        tmp_package_path = "#{package_path}.progress"
        tmp_meta_path = "#{meta_path}.progress"
        open(tmp_package_path, 'wb+') do |io|
          proxy_get(package_key, io)
        end
        open(tmp_meta_path, 'wb+') do |io|
          proxy_get(meta_key, io)
        end
        FileUtils.mv(tmp_package_path, package_path)
        FileUtils.mv(tmp_meta_path, meta_path)

        return Mamiya::Package.new(package_path)

      rescue NotFound, AlreadyFetched => e
        raise e

      rescue Exception => e
        File.unlink package_path if package_path && File.exists?(package_path)
        File.unlink meta_path if meta_path && File.exists?(meta_path)

        raise e
      end

      def meta(package_name)
        _, meta_key = package_and_meta_key_for(package_name)
        JSON.parse(proxy_get(meta_key, nil, &:body))
      rescue NotFound
        return nil
      end

      def self.s3_config(base) # :nodoc:
        superclass.s3_config(base).tap do |c|
          c.delete(:proxy_host)
          c.delete(:proxy_ssl_verify_none)
        end
      end

      private

      def proxy_host_uri
        @proxy_host_uri ||= URI.parse(@config[:proxy_host])
      end

      def connect_proxy(&block)
        Net::HTTP.new(proxy_host_uri.host, proxy_host_uri.port).tap do |http|
          http.use_ssl = (proxy_host_uri.scheme == 'https')
          if @config[:proxy_ssl_verify_none] == 'none'
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          end

          return http.start(&block)
        end
      end

      def proxy_get(key, target)
        connect_proxy do |http|
          http.request_get("#{proxy_host_uri.path}/#{@config[:bucket]}/#{key}") do |response|
            response.value

            if block_given?
              return yield(response)
            else
              response.read_body do |chunk|
                target.write chunk
              end
            end
          end
        end
      rescue Net::HTTPServerException => e
        if e.message.start_with?('404 ')
          raise NotFound
        else
          raise e
        end
      end
    end
  end
end
