require 'mamiya/master'

module Mamiya
  class Master
    module AgentMonitorHandlers
      def fetch_result__ack(status, payload, event)
        status['fetcher'] ||= {}
        status['fetcher']['pending'] = payload['pending']
      end

      def fetch_result__start(status, payload, event)
        status['fetcher'] ||= {}
        status['fetcher']['fetching'] = [payload['application'], payload['package']]
      end

      def fetch_result__error(status, payload, event)
        status['fetcher'] ||= {}

        if status['fetcher']['fetching'] == [payload['application'], payload['package']]
          status['fetcher']['fetching'] = nil
        end
      end

      def fetch_result__success(status, payload, event)
        status['fetcher'] ||= {}

        if status['fetcher']['fetching'] == [payload['application'], payload['package']]
          status['fetcher']['fetching'] = nil
        end

        status['packages'] ||= {}
        status['packages'][payload['application']] ||= []
        status['packages'][payload['application']] << payload['package']
      end

      def fetch_result__remove(status, payload, event)
        status['packages'] ||= {}
        packages = status['packages'][payload['application']]
        packages.delete(payload['package']) if packages
      end

    end
  end
end
