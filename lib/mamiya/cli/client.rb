require 'mamiya/cli'

require 'net/http'
require 'net/https'
require 'rack/utils'
require 'uri'
require 'json'
require 'thor'

require 'mamiya/util/label_matcher'

module Mamiya
  class CLI < Thor
    class Client < Thor
      class_option :master, aliases: '-u', type: :string, default: 'http://localhost:7761/'
      class_option :application, aliases: %w(-a --app), type: :string

      desc "list-applications", "list applications"
      def list_applications
        puts master_get('/packages')["applications"]
      end

      desc "list-packages", "list-packages"
      def list_packages
        puts master_get("/packages/#{application}")["packages"]
      end

      desc "show-package", "show package meta data"
      method_option :format, aliases: %w(-f), type: :string, default: 'pp'
      def show_package(package)
        meta = @meta =  master_get("/packages/#{application}/#{package}")

        case options[:format]
        when 'pp'
          require 'pp'
          pp meta
        when 'json'
          require 'json'
          puts meta.to_json
        when 'yaml'
          require 'yaml'
          puts meta.to_yaml
        end
      end

      desc "list-agents", 'list agents'
      method_option :labels, type: :string
      def list_agents
        params = options[:labels] ? {labels: options[:labels]} : {}
        payload = master_get("/agents", params)

        agents = payload["agents"].keys

        agents.each do |agent|
          puts "#{agent}\talive"
        end
        payload["failed_agents"].each do |agent|
          puts "#{agent}\tfailed"
        end
      end

      desc "show-agent AGENT", 'Show agent'
      method_option :format, aliases: %w(-f), type: :string, default: 'pp'
      def show_agent(agent)
        agent = master_get("/agents/#{agent}")

        case options[:format]
        when 'pp'
          require 'pp'
          pp agent
        when 'json'
          require 'json'
          puts agent.to_json
        when 'yaml'
          require 'yaml'
          puts agent.to_yaml
        end
      end

      # TODO: Deprecated. Remove this
      desc "show-distribution package", "Show package distribution status"
      method_option :format, aliases: %w(-f), type: :string, default: 'text'
      method_option :verbose, aliases: %w(-v), type: :boolean
      method_option :labels, type: :string
      def show_distribution(package)
        params = options[:labels] ? {labels: options[:labels]} : {}
        dist = master_get("/packages/#{application}/#{package}/distribution", params)

        case options[:format]
        when 'json'
          require 'json'
          puts dist.to_json
          return

        when 'yaml'
          require 'yaml'
          puts dist.to_yaml
          return
        end

        total = dist['distributed_count'] + dist['fetching_count'] +
          dist['queued_count'] + dist['not_distributed_count'] 

        progress = "%.1f" % ((dist['distributed_count']/total.to_f)*100)
        puts <<-EOF
package:         #{application}/#{package}
status:          #{dist['status']}
progress:        #{progress}

distributed:     #{dist['distributed_count']} agents
fetching:        #{dist['fetching_count']} agents
queued:          #{dist['queued_count']} agents
not distributed: #{dist['not_distributed_count']} agents
        EOF

        if options[:verbose]
          puts ""
          dist['distributed'].each do |name|
            puts "#{name}\tdistributed"
          end
          dist['queued'].each do |name|
            puts "#{name}\tqueued"
          end
          dist['not_distributed'].each do |name|
            puts "#{name}\tnot_distributed"
          end

        end
      end

      desc "status [PACKAGE]", "Show application or package status"
      method_option :format, aliases: %w(-f), type: :string, default: 'text'
      method_option :labels, type: :string
      method_option :show_done, type: :boolean, default: false
      def status(package=nil)
        if package
          pkg_status package
        else
          app_status
        end
      end

          
      desc "distribute package", "order distributing package to agents"
      method_option :labels, type: :string
      def distribute(package)
        params = options[:labels] ?
          {labels: Mamiya::Util::LabelMatcher.parse_string_expr(options[:labels])} : {}

        p master_post("/packages/#{application}/#{package}/distribute", params.merge(type: :json))
      end

      desc "prepare PACKAGE", "order preparing package to agents"
      method_option :labels, type: :string
      def prepare(package)
        params = options[:labels] ?
          {labels: Mamiya::Util::LabelMatcher.parse_string_expr(options[:labels])} : {}

        p master_post("/packages/#{application}/#{package}/prepare", params.merge(type: :json))
      end

      desc "switch PACKAGE", "order switching package to agents"
      method_option :labels, type: :string
      method_option :no_release, type: :boolean, default: false
      def switch(package)
        params = {no_release: options[:no_release]}
        if options[:labels]
          params[:labels] = Mamiya::Util::LabelMatcher.parse_string_expr(options[:labels])
        end

        p master_post("/packages/#{application}/#{package}/switch", params.merge(type: :json))
      end

      desc "refresh", "order refreshing agent status"
      def refresh
        p master_post('/agents/refresh')
      end

      desc "deploy PACKAGE", "Prepare, then switch"
      method_option :labels, type: :string
      method_option :no_release, type: :boolean, default: false
      method_option :config, aliases: '-C', type: :string
      method_option :no_switch, type: :boolean, default: false
      def deploy(package)
        @deploy_exception = nil
        # TODO: move this run on master node side
        puts "=> Deploying #{application}/#{package}"
        puts " * onto agents which labeled: #{options[:labels].inspect}" if options[:labels] && !options[:labels].empty?

        show_package(package)

        if config
          config.set :application, application
          config.set :package_name, package
          config.set :package, @meta

          config.before_deploy_or_rollback[]
          config.before_deploy[]
        end

        do_prep = -> do
          puts "=> Preparing..."
          prepare(package)
        end

        do_prep[]

        puts " * Wait until prepared"
        puts ""

        i = 0
        loop do
          i += 1
          do_prep[] if i % 25 == 0

          s = pkg_status(package, :short)
          puts ""
          break if 0 < s['participants_count'] && s['participants_count'] == s['prepare']['done'].size
          sleep 2
        end

        ###

        unless options[:no_switch]
          puts "=> Switching..."
          switch(package)

          puts " * Wait until switch"
          puts ""
          loop do
            s = pkg_status(package, :short)
            puts ""
            break if s['participants_count'] == s['switch']['done'].size
            sleep 2
          end
        end
      rescue Exception => e
        @deploy_exception = e
        $stderr.puts "ERROR: #{e.inspect}"
        $stderr.puts "\t#{e.backtrace.join("\n\t")}"
      ensure
        config.after_deploy[@deploy_exception] if config
        config.after_deploy_or_rollback[@deploy_exception] if config
        puts "=> Done."
      end

      desc "rollback", "Switch back to previous release then finalize"
      method_option :labels, type: :string
      method_option :no_release, type: :boolean, default: false
      method_option :config, aliases: '-C', type: :string
      def rollback
        @deploy_exception = nil
        # TODO: move this run on master node side
        appstatus = master_get("/applications/#{application}/status", options[:labels] ? {labels: options[:labels]} : {})
        package = appstatus['common_previous_release']

        unless package
          raise 'there is no common_previous_release for specified application'
        end

        puts "=> Rolling back #{application} to #{package}"
        puts " * with labels: #{options[:labels].inspect}" if options[:labels] && !options[:labels].empty?

        show_package(package)

        if config
          config.set :application, application
          config.set :package_name, package
          config.set :package, @meta

          config.before_deploy_or_rollback[]
          config.before_rollback[]
        end

        switch(package)

        puts " * Wait until switch"
        puts ""
        loop do
          s = pkg_status(package, :short)
          puts ""
          break if 0 < s['participants_count'] && s['participants_count'] == s['switch']['done'].size
          sleep 2
        end
      rescue Exception => e
        @deploy_exception = e
        raise e
      ensure
        config.after_rollback[@deploy_exception] if config
        config.after_deploy_or_rollback[@deploy_exception] if config
        puts "=> Done."
      end

      desc "join HOST", "let serf to join to HOST"
      def join(host)
        master_post('/join', host: host)
      end

      private

      def fatal!(msg)
        $stderr.puts msg
        exit 1
      end

      def application
        options[:application] or fatal!('specify application')
      end

      def config
        return @config if @config
        path = [options[:config], './mamiya.conf.rb', './config.rb', '/etc/mamiya/config.rb'].compact.find { |_| File.exists?(_) }

        if path
          @config = Mamiya::Configuration.new.load!(File.expand_path(path))
        end

        @config
      end

      def master_get(path, params={})
        path += "?#{Rack::Utils.build_query(params)}" unless params.empty?
        master_http.start do |http|
          JSON.parse http.get(path).tap(&:value).body
        end
      end

      def master_post(path, data='')
        response = nil
        master_http.start do |http|
          headers = {}

          if Hash === data
            case data.delete(:type) || :query
            when :json
              data = data.to_json
              headers['Content-Type'] = 'application/json'
            when :query
              data = Rack::Utils.build_nested_query(data)
            end
          end

          response = http.post(path, data, headers)
          response.value
          response.code == '204' ? true : JSON.parse(response.body)
        end
      rescue Net::HTTPExceptions => e
        puts response.body rescue nil
        raise e
      end

      def master_http
        url = master_url
        Net::HTTP.new(url.host, url.port).tap do |http|
          http.use_ssl = true if url.scheme == 'https'
        end
      end

      def master_url
        url = ENV["MAMIYA_MASTER_URL"] || options[:master]
        fatal! 'specify master URL via --master(-u) option or $MAMIYA_MASTER_URL' unless url
        URI.parse(url)
      end

      def app_status
        params = options[:labels] ? {labels: options[:labels]} : {}
        status = master_get("/applications/#{application}/status", params)

        case options[:format]
        when 'json'
          require 'json'
          puts status.to_json
          return

        when 'yaml'
          require 'yaml'
          puts status.to_yaml
          return

        end

        puts <<-EOF
at: #{Time.now.inspect}
application: #{application}
participants: #{status['participants_count']} agents

major_current: #{status['major_current']}
currents:
#{status['currents'].sort_by { |pkg, as| -(as.size) }.flat_map { |pkg, as|
["  - #{pkg} (#{as.size} agents)"] + (pkg == status['major_current'] ? [] : as.map{ |_| "    * #{_}" })
}.join("\n")}

common_previous_release: #{status['common_previous_release']}
common_releases:
#{status['common_releases'].map { |_| _.prepend('  - ') }.join("\n")}
        EOF
      end

      def pkg_status(package, short=false)
        params = options[:labels] ? {labels: options[:labels]} : {}
        status = master_get("/packages/#{application}/#{package}/status", params)

        case options[:format]
        when 'json'
          require 'json'
          puts status.to_json
          return

        when 'yaml'
          require 'yaml'
          puts status.to_yaml
          return

        end

        total = status['participants_count']

        if short
          puts "#{Time.now.strftime("%H:%M:%S")}  app:#{application} pkg:#{package}  agents:#{total}"
        else
          puts <<-EOF
at: #{Time.now.inspect}
package: #{application}/#{package}
status: #{status['status'].join(',')}

participants: #{total} agents

          EOF
        end

          %w(fetch prepare switch).each do |key|
            status[key].tap do |st|
              puts "#{key}: queued=#{st['queued'].size}, working=#{st['working'].size}, done=#{st['done'].size}"
              puts "  * queued:  #{st['queued'].join(', ')}" if !st['queued'].empty? && st['queued'].size != total
              puts "  * working: #{st['working'].join(', ')}" if !st['working'].empty? && st['working'].size != total
              puts "  * done:    #{st['done'].join(', ')}" if !st['done'].empty? && options[:show_done] && st['done'].size != total
            end
          end

        status
      end
    end

   desc "client", "client for master"
   subcommand "client", Client
  end
end
