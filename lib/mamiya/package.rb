module Mamiya
  class Package
    class NotExists < Exception; end

    def initialize(path)
    end

    attr_accessor :meta
  end
end
