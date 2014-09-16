require 'mamiya/version'
require 'mamiya/agent'
require 'sinatra/base'
require 'mamiya/util/label_matcher'
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

        def parse_label_matcher_expr(str)
          Mamiya::Util::LabelMatcher.parse_string_expr(str)
        end
      end

      before do
        if request.content_type == 'application/json'
          begin
            params.merge! JSON.parse(request.body.read)
          rescue JSON::ParserError
            halt :bad_request
          end
        end
      end

      get '/' do
        content_type 'text/plain'
        "mamiya v#{Mamiya::VERSION}\n"
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
          master.distribute(params[:application], params[:package], labels: params['labels'])
        else
          status 404
          content_type :json
          {error: 'not found'}.to_json
        end
      end

      post '/packages/:application/:package/prepare' do
        # TODO: filter with label
        if storage(params[:application]).meta(params[:package])
          status 204
          master.prepare(params[:application], params[:package], labels: params['labels'])
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

        expr = params[:labels] && parse_label_matcher_expr(params[:labels])
        pkgstatus = agent_monitor.package_status(params[:application], params[:package], labels: expr)

        result = {
          application: params[:application],
          package: params[:package],
          distributed: pkgstatus.fetched_agents,
          fetching: pkgstatus.fetching_agents,
          queued: pkgstatus.fetch_queued_agents,
          not_distributed: pkgstatus.non_participants,
        }

        result[:distributed_count] = result[:distributed].size
        result[:fetching_count] = result[:fetching].size
        result[:not_distributed_count] = result[:not_distributed].size
        result[:queued_count] = result[:queued].size

        total = agent_monitor.statuses.size

        case
        when 0 < result[:queued_count] || 0 < result[:fetching_count]
          status = :distributing
        when 0 < result[:distributed_count] && result[:distributed_count] < total
          status = :partially_distributed
        when result[:distributed_count] == total
          status = :distributed
        else
          status = :unknown
        end

        result[:status] = status

        if params[:count_only]
          result.delete :distributed
          result.delete :fetching
          result.delete :queued
          result.delete :not_distributed
        end

        result.to_json
      end

      get '/agents' do
        expr = params[:labels] ? parse_label_matcher_expr(params[:labels]) : nil

        last_refresh_at = agent_monitor.last_refresh_at
        statuses = agent_monitor.statuses(labels: expr)
        members = agent_monitor.agents
        failed_agents = agent_monitor.failed_agents

        agents = {}
        members.each do |name, status|
          next unless status["status"] == "alive"

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

        if params[:labels]
          agents.select! { |k,v| v['status'] }
        end

        content_type :json

        {
          last_refresh_at: agent_monitor.last_refresh_at,
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
