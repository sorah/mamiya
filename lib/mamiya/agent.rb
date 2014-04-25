require 'thread'
require 'villein'
require 'mamiya/logger'

require 'mamiya/steps/fetch'
require 'mamiya/agent/fetcher'

require 'mamiya/agent/handlers/fetch'

module Mamiya
  class Agent
    def initialize(config, logger: Mamiya::Logger.new, events_only: nil)
      @config = config
      @serf = init_serf
      @events_only = events_only

      @fetcher = Mamiya::Agent::Fetcher.new(config)
      @logger = logger['agent']
    end

    attr_reader :config, :serf, :logger, :fetcher

    def run!
      logger.info "Starting..."

      serf_start
      fetcher_start

      logger.info "Started."

      loop do
        sleep 10
      end
    end

    def update_tags
      # TODO:
      # serf.tags.update(
    end

    def status
    end

    def releases
    end

    private

    def init_serf
      agent_config = (config[:serf] && config[:serf][:agent]) || {}
      Villein::Agent.new(**agent_config).tap do |serf|
        serf.on_user_event do |event|
          user_event_handler(event)
        end
      end
    end

    def serf_start
      logger.debug "Starting serf"

      @serf.start!
      @serf.auto_stop
      @serf.wait_for_ready

      logger.debug "Serf became ready"
    end

    def fetcher_start
      logger.debug "Starting fetcher"

      @fetcher.start!
    end

    def user_event_handler(event)
      user_event, payload = event.user_event, JSON.parse(event.payload)

      return unless user_event.start_with?('mamiya:')
      user_event.sub!(/^mamiya:/, '')

      type, action = event.user_event.split(/:/, 2)

      return if @events_only && !@events_only.any?{ |_| _ === type }

      class_name = type.capitalize.gsub(/-./) { |_| _[1].upcase }

      logger.debug "Received user event #{type}"
      logger.debug payload.inspect

      if Handlers.const_defined?(class_name)
        Handlers.const_get(class_name).new(self, event).run!
      else
        logger.warn("Discarded event[#{event.user_event}] because we don't handle it")
      end
    rescue Exception => e
      logger.fatal("Error during handling event: #{e.inspect}")
      e.backtrace.each do |line|
        logger.fatal line.prepend("\t")
      end

      raise e if $0.end_with?('rspec')
    rescue JSON::ParserError
      logger.warn("Discarded event[#{event.user_event}] with invalid payload (unable to parse as json)")
    end
  end
end
