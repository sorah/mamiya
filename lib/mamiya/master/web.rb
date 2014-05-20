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

        def agent_monitor
          master.agent_monitor
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
        # TODO: filter with label
        if storage(params[:application]).meta(params[:package])
          status 204
          master.distribute(params[:application], params[:package])
        else
          status 404
          content_type :json
          {error: 'not found'}.to_json
        end
      end

      get '/agents' do
        statuses = agent_monitor.statuses
        members = agent_monitor.agents
        failed_agents = agent_monitor.failed_agents

        agents = {}
        members.each do |name, status|
          agents[name] ||= {}
          agents[name]["membership"] = status
        end

        statuses.each do |name, status|
          if status["master"]
            agents.delete name
            next
          end

          agents[name] ||= {}
          agents[name]["status"] = status
        end


        content_type :json

        {
          agents: agents,
          failed_agents: failed_agents,
        }.to_json
      end
    end
  end
end
