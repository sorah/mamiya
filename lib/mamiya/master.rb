require 'mamiya/agent'
require 'mamiya/master/web'
require 'mamiya/master/agent_monitor'

module Mamiya
  class Master < Agent
    MASTER_EVENTS = %i(aaaa)

    def initialize(*)
      super

      @agent_monitor = AgentMonitor.new(self)
      @events_only ||= []
      @events_only << MASTER_EVENTS
    end

    attr_reader :agent_monitor

    def web
      logger = self.logger
      this = self

      @web ||= Rack::Builder.new do
        use AppBridge, logger, this
        run Web
      end
    end

    def start
      # Override and stop starting fetcher
      web_start
      serf_start
      monitor_start
    end

    def distribute(application, package)
      trigger(:fetch, application: application, package: package)
    end

    def storage(app)
      config.storage_class.new(
        config[:storage].merge(
          application: app
        )
      )
    end

    def status
      {name: serf.name, master: true}
    end

    private

    def web_start
      @web_thread = Thread.new do
        options = config[:web] || {}
        rack_options = {
          app: self.web,
          Port: options[:port].to_i,
          Host: options[:bind],
          environment: options[:environment],
          server: options[:server],
          Logger: logger['web']
        }
        server = Rack::Server.new(rack_options)
        # To disable trap(:INT) and trap(:TERM)
        server.define_singleton_method(:trap) { |*args| }
        server.start
      end
      @web_thread.abort_on_exception = true
    end

    def monitor_start
      logger.debug "Starting agent_monitor..."
      @agent_monitor.start!
      logger.debug "agent_monitor became ready"
    end

    class AppBridge
      def initialize(app, log, this)
        @app, @logger, @this = app, log['web'], this
      end

      def call(env)
        env['rack.logger'] = @logger
        env['mamiya.master'] = @this
        @app.call(env)
      end
    end
  end
end
