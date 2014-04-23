require 'thread'
require 'villein'
require 'mamiya/logger'

require 'mamiya/steps/fetch'
require 'mamiya/agent/fetcher'

require 'mamiya/agent/handlers/fetch'

module Mamiya
  class Agent
    def initialize(config, logger: Mamiya::Logger.new)
      @config = config
      @serf = init_serf
      @fetcher = Mamiya::Agent::Fetcher.new(destination: config[:packages_dir])
      @logger = logger['agent']
    end

    attr_reader :config, :serf, :logger, :fetcher

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
      class_name = type.sub(/^mamiya-/,'').capitalize.gsub(/_./) { |_| _[1].upcase }

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

    def handle_fetch_event(payload, event)

    end

  end
end
