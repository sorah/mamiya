require 'thread'
require 'villein'
require 'mamiya/logger'

require 'mamiya/steps/fetch'
require 'mamiya/agent/fetcher'

module Mamiya
  class Agent
    FETCH_ACK_EVENT = 'mamiya-fetch-ack'
    FETCH_SUCCESS_EVENT = 'mamiya-fetch-success'
    FETCH_ERROR_EVENT = 'mamiya-fetch-error'

    def initialize(config, logger: Mamiya::Logger.new)
      @config = config
      @serf = init_serf
      @fetcher = Mamiya::Agent::Fetcher.new(destination: config[:packages_dir])
      @logger = logger['agent']
    end

    attr_reader :config, :serf, :logger

    def run!
      serf_start
      fetcher_start

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
      Villein::Agent.new(**config[:serf][:agent]).tap do |serf|
        serf.on_user_event do |event|
          user_event_handler(event)
        end
      end
    end

    def serf_start
      @serf.start!
      @serf.auto_stop
    end

    def fetcher_start
      @fetcher.start!
    end

    def user_event_handler(event)
      type, payload = event.user_event, JSON.parse(event.payload)
      method = "handle_#{type.sub(/^mamiya-/,'').gsub(/-/,'_')}_event"

      if respond_to?(method, true)
        self.__send__(method, payload, event)
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

    def handle_fetch_event(payload, event)
      serf.event(FETCH_ACK_EVENT,
        {
          name: serf.name,
          application: payload['application'],
          package: payload['package']
        }.to_json
      )

      @fetcher.enqueue(payload['application'], payload['package']) do |error|
        if error
          serf.event(FETCH_ERROR_EVENT,
            {
              name: serf.name,
              application: payload['application'],
              package: payload['package'],
              error: error.inspect,
            }.to_json
          )
        else
          serf.event(FETCH_SUCCESS_EVENT,
            {
              name: serf.name,
              application: payload['application'],
              package: payload['package'],
            }.to_json
          )
        end

        update_tags
      end
    end

  end
end
