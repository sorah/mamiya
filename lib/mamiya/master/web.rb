require 'mamiya/version'
require 'mamiya/agent'
require 'sinatra/base'
require 'json'

module Mamiya
  class Master < Agent
    class Web < Sinatra::Base
      get '/' do
        "mamiya v#{Mamiya::VERSION}"
      end
    end
  end
end
