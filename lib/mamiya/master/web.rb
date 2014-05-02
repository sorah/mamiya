require 'mamiya/version'
require 'mamiya/agent'
require 'sinatra/base'
require 'json'

module Mamiya
  class Master < Agent
    class Web < Sinatra::Base
      helpers do
        def master
          env['mamiya.master']
        end

        def storage(app)
          master.storage(app)
        end
      end

      get '/' do
        "mamiya v#{Mamiya::VERSION}"
      end

      get '/packages/:application' do
        content_type :json
        packages = storage(params[:application]).packages

        status 404 if packages.empty?
        {packages: packages}.to_json
      end

      get '/packages/:application/:package' do
        content_type :json

        meta = storage(params[:application]).meta(params[:package])

        if meta
          {application: params[:application], name: params[:package],
           meta: meta}.to_json
        else
          status 404
          {}.to_json
        end
      end

      post '/packages/:application/:package/distribute' do
      end
    end
  end
end
