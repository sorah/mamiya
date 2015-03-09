require 'mamiya/master'

module Mamiya
  class Master
    ##
    # This class determines application cluster's status (what's majority package active, etc).
    class ApplicationStatus
      def initialize(agent_monitor, application, labels: nil)
        @application = application
        @labels = labels
        @agents = agent_monitor.statuses(labels: labels).reject { |_, s| s['master'] }
      end

      attr_reader :labels, :application, :agents

      def to_hash
        {
          application: application,
          labels: labels,
          participants_count: participants.size,
          agents_count: agents.size,
          non_participants: non_participants,

          major_current: major_current,
          currents: currents,

          common_releases: common_releases,
          common_previous_release: common_previous_release,
        }
      end

      def participants
        @participants ||= Hash[agents.select do |name, status|
          (status['currents']    && status['currents'][application])    || \
          (status['releases']    && status['releases'][application])    || \
          (status['prereleases'] && status['prereleases'][application]) || \
          (status['packages']    && status['packages'][application])    || \

          (status['queues'] && status['queues'].any? { |_, q|
            (q['working'] && q['working']['app'] == application) || \
            (q['queue']   && q['queue'].any? { |t| t['app'] == application })
          })
        end]
      end

      def non_participants
        agents.keys - participants.keys
      end

      def currents
        @currents ||= Hash[participants.group_by do |name, status|
          status['currents'] && status['currents'][application]
        end.map { |package, as| [package, as.map(&:first).sort] }]
      end

      def major_current
        @major_current ||= currents.max_by { |package, as| as.size }[0]
      end

      def common_releases
        #@common_releases ||= participants.map { |_| _[].select { |package, as| as.size > 2 }.map(&:first).compact.sort
        @common_releases ||= participants.
          map { |name, agent| agent['releases'] && agent['releases'][application] }.
          compact.
          inject(:&).
          sort
      end

      def common_previous_release
        idx = common_releases.index(major_current)
        return if !idx || idx < 1

        common_releases[idx-1]
      end
    end
  end
end

