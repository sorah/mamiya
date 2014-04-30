require 'mamiya/agent'
require 'mamiya/master/web'

module Mamiya
  class Master < Agent
    MASTER_EVENTS = %i(aaaa)

    def initialize(*)
      super

      @events_only ||= []
      @events_only << MASTER_EVENTS
    end

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
        server.define_singleton_method(:trap) { |*args| }
        server.start
      end
      @web_thread.abort_on_exception = true
    end

    class AppBridge
      def initialize(app, log, this)
        @app, @logger, @this = app, log, this
      end

      def call(env)
        env['rack.logger'] = @logger['web']
        env['mamiya.master'] = this
        @app.call(env)
      end
    end
  end
end
