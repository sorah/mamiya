require 'mamiya/master'

module Mamiya
  class Master
    # XXX: TODO:
    module AgentMonitorHandlers
      def task__start(status, payload, event)
        task = payload['task']

        status['task_queues'] ||= {}
        status['task_queues'][task['task']] ||= {'queue' => [], 'working' => nil}

        status['task_queues'][task['task']]['working'] = task
        status['task_queues'][task['task']]['queue'].delete task
      end

      def task__finalize(status, payload, event)
        task = payload['task']

        status['task_queues'] ||= {}
        status['task_queues'][task['task']] ||= {'queue' => [], 'working' => nil}

        s = status['task_queues'][task['task']]
        if s['working'] == task
          s['working'] = nil
        end
        status['task_queues'][task['task']]['queue'].delete task
      end

      def task__finish(status, payload, event)
        task = payload['task']
        logger.error "#{status['name']} finished task #{task['task']}: #{payload['error']}"

        task__finalize(status, payload, event)
      end

      def task__error(status, payload, event)
        task = payload['task']
        logger.error "#{status['name']} failed task #{task['task']}: #{payload['error']}"

        task__finalize(status, payload, event)
      end

      def fetch_result__ack(status, payload, event)
        status['fetcher'] ||= {}
        status['fetcher']['pending'] = payload['pending']

        status['fetcher']['pending_jobs'] ||= []
        status['fetcher']['pending_jobs'] << [payload['application'], payload['package']]
      end

      def fetch_result__start(status, payload, event)
        status['fetcher'] ||= {}
        status['fetcher']['fetching'] = [payload['application'], payload['package']]

        logger.debug "#{status['name']} started to fetch #{payload['application']}/#{payload['package']}"

        status['fetcher']['pending_jobs'] ||= []
        status['fetcher']['pending_jobs'].delete [payload['application'], payload['package']]
      end

      def fetch_result__error(status, payload, event)
        status['fetcher'] ||= {}

        logger.error "#{status['name']} failed to fetch #{payload['application']}/#{payload['package']}: #{payload['error']}"

        if status['fetcher']['fetching'] == [payload['application'], payload['package']]
          status['fetcher']['fetching'] = nil
        end
      end

      def fetch_result__success(status, payload, event)
        status['fetcher'] ||= {}

        logger.info "#{status['name']} fetched #{payload['application']}/#{payload['package']}"

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
