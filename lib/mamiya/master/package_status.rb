require 'mamiya/master'

module Mamiya
  class Master
    ##
    # This class determines distribution and releasing status of given package using given AgentMonitor.
    class PackageStatus
      def initialize(agent_monitor, application, package, labels: nil)
        @application = application
        @package = package
        @agents = agent_monitor.statuses(labels: @labels).reject { |_, s| s['master'] }
        @labels = labels
      end

      attr_reader :labels, :application, :package, :agents

      def to_hash
        {
          application: application,
          package: package,
          labels: labels,
          status: status,
          participants_count: participants.size,
          non_participants: non_participants,
          active: current_agents,
          fetch: {
            queued: fetch_queued_agents,
            working: fetching_agents,
            done: fetched_agents,
          },
          prepare: {
            queued: prepare_queued_agents,
            working: preparing_agents,
            done: prepared_agents,
          },
          switch: {
            queued: switch_queued_agents,
            working: switching_agents,
            done: current_agents,
          },
        }
      end

      def status
        [].tap do |s|
          case
          when fetched_agents == agents.keys
            s << :distributed
          when !fetching_agents.empty? || !fetch_queued_agents.empty?
            s << :distributing
          end
          if fetched_agents != agents.keys && !fetched_agents.empty?
            s << :partially_distributed
          end

          s << :unknown if s.empty?
        end
      end

      def fetch_queued_agents
        agents.select do |name, agent|
          queue = agent['queues'] && agent['queues']['fetch'] && agent['queues']['fetch']['queue']
          queue && queue.any? { |task|
            app_and_pkg == task.values_at('app', 'pkg')
          }
        end.keys
      end

      def fetching_agents
        agents.select do |name, agent|
          task = agent['queues'] && agent['queues']['fetch'] && agent['queues']['fetch'] && agent['queues']['fetch']['working']
          task && app_and_pkg == task.values_at('app', 'pkg')
        end.keys
      end

      def fetched_agents
        agents.select do |name, agent|
          packages = agent['packages'] && agent['packages'][application]
          packages && packages.include?(package)
        end.keys
      end

      def prepare_queued_agents
        agents.select do |name, agent|
          queue = agent['queues'] && agent['queues']['prepare'] && agent['queues']['prepare']['queue']
          queue && queue.any? { |task|
            app_and_pkg == task.values_at('app', 'pkg')
          }
        end.keys
      end

      def preparing_agents
        agents.select do |name, agent|
          task = agent['queues'] && agent['queues']['prepare'] && agent['queues']['prepare'] && agent['queues']['prepare']['working']
          task && app_and_pkg == task.values_at('app', 'pkg')
        end.keys
      end

      def prepared_agents
        agents.select do |name, agent|
          packages = agent['prereleases'] && agent['prereleases'][application]
          packages && packages.include?(package)
        end.keys
      end

      def switch_queued_agents
        agents.select do |name, agent|
          queue = agent['queues'] && agent['queues']['switch'] && agent['queues']['switch']['queue']
          queue && queue.any? { |task|
            app_and_pkg == task.values_at('app', 'pkg')
          }
        end.keys
      end

      def switching_agents
        agents.select do |name, agent|
          task = agent['queues'] && agent['queues']['switch'] && agent['queues']['switch'] && agent['queues']['switch']['working']
          task && app_and_pkg == task.values_at('app', 'pkg')
        end.keys
      end

      def current_agents
        agents.select do |name, agent|
          current = agent['currents'] && agent['currents'][application]
          current == package
        end.keys
      end

      def participants
        fetch_queued_agents   + fetching_agents  + fetched_agents  + \
        prepare_queued_agents + preparing_agents + prepared_agents + \
        switch_queued_agents  + switching_agents + current_agents
      end

      def non_participants
        agents.keys - participants
      end

      def reload
        @agents = nil
      end

      private

      def app_and_pkg
        @app_and_pkg ||= [application, package]
      end
    end
  end
end
