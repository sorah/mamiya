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

      get '/packages' do
        content_type :json
        applications = master.applications

        {applications: applications}.to_json
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

      get '/packages/:application/:package/distribution' do
        # TODO: filter with label
        content_type :json
        meta = storage(params[:application]).meta(params[:package])
        unless meta
          status 404
          next {error: 'not found'}.to_json
        end

        result = {application: params[:application], package: params[:package], distributed: [], not_distributed: []}
        statuses = agent_monitor.statuses

        statuses.each do |name, status|
          next if status["master"]
          if status["packages"] && status["packages"][params[:application]] &&
            status["packages"][params[:application]].include?(params[:package])

            result[:distributed] << name
          else
            result[:not_distributed] << name
          end
        end

        result[:distributed_count] = result[:distributed].size
        result[:not_distributed_count] = result[:not_distributed].size

        result.to_json
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

      get '/agents/:name' do
        content_type :json

        status = agent_monitor.statuses[params[:name]]
        membership = agent_monitor.agents[params[:name]]

        if status || membership
          {name: params[:name], status: status, membership: membership}.to_json
        else
          status 404
          {error: 'not found'}.to_json
        end
      end

      post '/agents/refresh' do
        agent_monitor.refresh
        status 204
      end

      post '/join' do
        begin
          master.serf.join(params[:host])
          status 204
        rescue Villein::Client::SerfError => e
          raise e unless /Error joining the cluster/ === e.message

          content_type :json
          status 400
          {error: e.message}.to_json
        end
      end
    end
  end
end
