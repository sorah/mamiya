module Mamiya
  module Storages
    def self.find(name)
      name = name.to_s
      classish_name = name.capitalize.gsub(/_./) { |s| s[1].upcase }

      begin
        return const_get(classish_name)
      rescue NameError; end

      require "mamiya/storages/#{File.basename(name)}"
      const_get(classish_name)
    rescue NameError, LoadError
      return nil
    end
  end
end
