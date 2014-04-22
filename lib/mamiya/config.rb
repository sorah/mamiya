require 'yaml'
require 'mamiya/storages'

module Mamiya
  class Config
    def self.load(file)
      self.new YAML.load_file(file)
    end

    def initialize(config_hash = {})
      @config = symbolize_keys_in(config_hash)
    end

    def [](key)
      @config[key]
    end

    def storage_class
      self[:storage] && Storages.find(self[:storage][:type])
    end

    def deploy_to_for_app(app)
      # TODO: test
      app = app.to_sym

      if self[:apps] && self[:applications][app]
        Pathname.new(self[:applications][app][:deploy_to])
      end
    end

    def releases_path_for_app(app)
      # TODO: test
      deploy_to_for_app(app).join('releases')
    end

    private

    def symbolize_keys_in(hash)
      Hash[hash.map { |k, v|
        case v
        when Hash
          v = symbolize_keys_in(v)
        when Array
          if v.find { |_| _.kind_of?(Hash) }
            v = v.map { |_| _.kind_of?(Hash) ? symbolize_keys_in(_) : _ }
          end
        end

        [k.to_sym, v]
      }]
    end
  end
end
