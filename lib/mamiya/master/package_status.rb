require 'mamiya/master'

module Mamiya
  class Master
    ##
    # This class determines distribution and releasing status of given package using given AgentMonitor.
    class PackageStatus
      def initialize(agent_monitor, application, package, labels: nil)
        @application = application
        @package = package
        @labels = labels
        @agents = agent_monitor.statuses(labels: labels).reject { |_, s| s['master'] }
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
          working = false

          case
          when fetched_agents == agents.keys
            s << :distributed
          when !fetching_agents.empty? || !fetch_queued_agents.empty?
            working = true
            s << :distributing
          end
          if fetched_agents != agents.keys && !fetched_agents.empty?
            s << :partially_distributed
          end

          # TODO: FIXME: tests
          case
          when prepared_agents == agents.keys
            s << :prepared
          when !preparing_agents.empty? || !prepare_queued_agents.empty?
            working = true
            s << :preparing
          end
          if prepared_agents != agents.keys && !prepared_agents.empty?
            s << :partially_prepared
          end

          # TODO: FIXME: tests
          case
          when current_agents == agents.keys
            s << :active
          when !current_agents.empty? || !switch_queued_agents.empty?
            working = true
            s << :switching
          end
          if current_agents != agents.keys && !current_agents.empty?
            s << :partially_active
          end

          s << :unknown if s.empty?
          s << :working if working
        end
      end

      def fetch_queued_agents
        @fetch_queued_agents ||= agents.select do |name, agent|
          queue = agent['queues'] && agent['queues']['fetch'] && agent['queues']['fetch']['queue']
          queue && queue.any? { |task|
            app_and_pkg == task.values_at('app', 'pkg')
          }
        end.keys - fetched_agents
      end

      def fetching_agents
        @fetching_agents ||= agents.select do |name, agent|
          task = agent['queues'] && agent['queues']['fetch'] && agent['queues']['fetch'] && agent['queues']['fetch']['working']
          task && app_and_pkg == task.values_at('app', 'pkg')
        end.keys - fetched_agents
      end

      def fetched_agents
        @fetched_agents ||= agents.select do |name, agent|
          packages = agent['packages'] && agent['packages'][application]
          packages && packages.include?(package)
        end.keys
      end

      def prepare_queued_agents
        @prepare_queued_agents ||= agents.select do |name, agent|
          queue = agent['queues'] && agent['queues']['prepare'] && agent['queues']['prepare']['queue']
          queue && queue.any? { |task|
            app_and_pkg == task.values_at('app', 'pkg')
          }
        end.keys - prepared_agents
      end

      def preparing_agents
        @preparing_agents ||= agents.select do |name, agent|
          task = agent['queues'] && agent['queues']['prepare'] && agent['queues']['prepare'] && agent['queues']['prepare']['working']
          task && app_and_pkg == task.values_at('app', 'pkg')
        end.keys - prepared_agents
      end

      def prepared_agents
        @prepare_agents ||= agents.select do |name, agent|
          packages = agent['prereleases'] && agent['prereleases'][application]
          packages && packages.include?(package)
        end.keys
      end

      def switch_queued_agents
        @switch_queued_agents ||= agents.select do |name, agent|
          queue = agent['queues'] && agent['queues']['switch'] && agent['queues']['switch']['queue']
          queue && queue.any? { |task|
            app_and_pkg == task.values_at('app', 'pkg')
          }
        end.keys - current_agents
      end

      def switching_agents
        @switching_agents ||= agents.select do |name, agent|
          task = agent['queues'] && agent['queues']['switch'] && agent['queues']['switch'] && agent['queues']['switch']['working']
          task && app_and_pkg == task.values_at('app', 'pkg')
        end.keys - current_agents
      end

      def current_agents
        @current_agents ||= agents.select do |name, agent|
          current = agent['currents'] && agent['currents'][application]
          current == package
        end.keys
      end

      def participants
        (fetch_queued_agents   + fetching_agents  + fetched_agents  + \
        prepare_queued_agents + preparing_agents + prepared_agents + \
        switch_queued_agents  + switching_agents + current_agents).uniq
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
