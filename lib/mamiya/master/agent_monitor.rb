require 'json'
require 'set'

require 'mamiya/master'
require 'mamiya/master/agent_monitor_handlers'

module Mamiya
  class Master
    ##
    # Class to monitor agent's status. This collects all agents' status.
    # Statuses are updated by event from agent, and running serf query `mamiya:status` periodically.
    class AgentMonitor
      include AgentMonitorHandlers

      STATUS_QUERY = 'mamiya:status'.freeze
      DEFAULT_INTERVAL = 300

      def initialize(master, raise_exception: false)
        @master = master
        @interval = (master.config[:master] && 
                    master.config[:master][:monitor] &&
                    master.config[:master][:monitor][:refresh_interval]) ||
                    DEFAULT_INTERVAL
 
        @raise_exception = raise_exception

        @agents = {}.freeze
        @failed_agents = [].freeze
        @statuses = {}
      end

      attr_reader :statuses, :agents, :failed_agents

      def start!
        @thread ||= Thread.new do
          loop do
            self.work_loop
            sleep @interval
          end
        end
      end

      def stop!
        @thread.kill if running?
        @thread = nil
      end

      def running?
        @thread && @thread.alive?
      end

      def work_loop
        self.refresh
      rescue Exception => e
        raise e if @raise_exception

        logger.fatal "Periodical refreshing failed: #{e.class}: #{e.message}"
        e.backtrace.each do |line|
          logger.fatal "\t#{line}"
        end
      end

      def commit_event(event)
        logger.debug "Commiting #{event.user_event}"

        # TODO:

      rescue JSON::ParserError => e
        logger.warn "Failed to parse payload in event #{event.user_event}: #{e.message}"
      end

      def refresh
        logger.info "Refrashing..."

        new_agents = {}
        new_failed_agents = Set.new
        new_statuses = {}

        @master.serf.members.each do |member|
          new_agents[member["name"]] = member
          new_failed_agents.add(member["name"]) unless member["status"] == 'alive'
        end

        response = @master.serf.query(STATUS_QUERY, '')
        response["Responses"].each do |name, json|
          begin
            new_statuses[name] = JSON.parse(json)
          rescue JSON::ParserError => e
            logger.warn "Failed to parse status from #{name}: #{e.message}"
            new_failed_agents << name
            next
          end
        end

        new_failed_agents = new_failed_agents.to_a

        (new_agents.keys - @agents.keys).join(", ").tap do |agents|
          logger.info "Added agents: #{agents}" unless agents.empty?
        end

        (@agents.keys - new_agents.keys).join(", ").tap do |agents|
          logger.info "Removed agents: #{agents}" unless agents.empty?
        end

        (failed_agents - new_failed_agents).join(", ").tap do |agents|
          logger.info "Recovered agents: #{agents}" unless agents.empty?
        end

        (new_failed_agents - failed_agents).join(", ").tap do |agents|
          logger.info "Newly failed agents: #{agents}" unless agents.empty?
        end

        @agents = new_agents.freeze
        @failed_agents = new_failed_agents.freeze
        @statuses = new_statuses

        self
      end

      private

      def logger
        @logger ||= @master.logger['agent-monitor']
      end
    end
  end
end
