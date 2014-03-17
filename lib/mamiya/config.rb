require 'yaml'

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
