require 'json'
require 'set'
require 'thread'

require 'mamiya/master'
require 'mamiya/master/agent_monitor_handlers'
require 'mamiya/master/package_status'
require 'mamiya/master/application_status'

module Mamiya
  class Master
    ##
    # Class to monitor agent's status. This collects all agents' status.
    # Statuses are updated by event from agent, and running serf query `mamiya:status` periodically.
    class AgentMonitor
      include AgentMonitorHandlers

      STATUS_QUERY = 'mamiya:status'.freeze
      PACKAGES_QUERY = 'mamiya:packages'.freeze
      DEFAULT_INTERVAL = 60

      PACKAGE_STATUS_KEYS = %w(packages prereleases releases currents).map(&:freeze).freeze

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
        @commit_lock = Mutex.new
        @last_refresh_at = nil
      end

      attr_reader :agents, :failed_agents, :last_refresh_at

      def statuses(labels: nil, agents: nil)
          @statuses.select { |name, status|
            (labels ? status['labels'] &&
              Mamiya::Util::LabelMatcher::Simple.new(status['labels']).
              match?(labels) : true) &&
            (agents ? agents.include?(name) : true)
          }
      end

      def package_status(app, pkg, labels: nil, agents: nil)
        PackageStatus.new(self, app, pkg, labels: labels, agents: nil)
      end

      def application_status(app, labels: nil, agents: nil)
        ApplicationStatus.new(self, app, labels: labels, agents: nil)
      end

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
        @commit_lock.synchronize { commit_event_without_lock(event) }
      end

      def commit_event_without_lock(event)
        return unless /\Amamiya:/ === event.user_event

        method_name = event.user_event[7..-1].gsub(/:/, '__').gsub(/-/,'_')
        return unless self.respond_to?(method_name, true)

        payload = JSON.parse(event.payload)
        agent = @statuses[payload["name"]]
        return unless agent

        logger.debug "Commiting #{event.user_event}"
        logger.debug "- #{agent.inspect}"
        __send__ method_name, agent, payload, event
        logger.debug "+ #{agent.inspect}"

      rescue JSON::ParserError => e
        logger.warn "Failed to parse payload in event #{event.user_event}: #{e.message}"
      end

      def refresh(**kwargs)
        logger.debug "Refreshing..."

        new_agents = {}
        new_failed_agents = Set.new
        new_statuses = {}

        @master.serf.members.each do |member|
          new_agents[member["name"]] = member
          new_failed_agents.add(member["name"]) unless member["status"] == 'alive'
        end

        @commit_lock.synchronize { 
          if kwargs[:node]
            new_statuses = statuses.reject do |name, status|
              kwargs[:node].include?(name)
            end
          end

          status_query_th = Thread.new { @master.serf.query(STATUS_QUERY, '', **kwargs) }
          packages_query_th = Thread.new { @master.serf.query(PACKAGES_QUERY, '', **kwargs) }
          status_response = status_query_th.value
          packages_response = packages_query_th.value

          status_response["Responses"].each do |name, json|
            begin
              new_statuses[name] = JSON.parse(json)
            rescue JSON::ParserError => e
              logger.warn "Failed to parse status from #{name}: #{e.message}"
              new_failed_agents << name
              next
            end
          end

          packages_response["Responses"].each do |name, json|
            next unless new_statuses[name]

            begin
              resp = JSON.parse(json)

              PACKAGE_STATUS_KEYS.each do |k|
                new_statuses[name][k] = resp[k]
              end
            rescue JSON::ParserError => e
              logger.warn "Failed to parse packages from #{name}: #{e.message}"
              next
            end
          end

          (new_statuses.keys - packages_response["Responses"].keys).each do |name|
            PACKAGE_STATUS_KEYS.each do |k|
              if @statuses[name] && @statuses[name][k]
                new_statuses[name][k] = @statuses[name][k]
              end
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
          @last_refresh_at = Time.now
        }

        self
      end

      private

      def logger
        @logger ||= @master.logger.with_clean_progname['agent-monitor']
      end
    end
  end
end
