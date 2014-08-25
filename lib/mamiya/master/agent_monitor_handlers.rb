require 'mamiya/master'

module Mamiya
  class Master
    # XXX: TODO:
    module AgentMonitorHandlers
      def task__start(status, payload, event)
        task = payload['task']

        status['queues'] ||= {}
        status['queues'][task['task']] ||= {'queue' => [], 'working' => nil}

        status['queues'][task['task']]['working'] = task
        status['queues'][task['task']]['queue'].delete task
      end

      def task__finalize(status, payload, event)
        task = payload['task']

        status['queues'] ||= {}
        status['queues'][task['task']] ||= {'queue' => [], 'working' => nil}

        s = status['queues'][task['task']]
        if s['working'] == task
          s['working'] = nil
        end
        status['queues'][task['task']]['queue'].delete task
      end

      def task__finish(status, payload, event)
        task = payload['task']
        logger.error "#{status['name']} finished task #{task['task']}: #{payload['error']}"

        task__finalize(status, payload, event)

        method_name = "task___#{task['task']}__finish"
        if self.respond_to?(method_name)
          __send__ method_name, status, task
        end
      end

      def task__error(status, payload, event)
        task = payload['task']
        logger.error "#{status['name']} failed task #{task['task']}: #{payload['error']}"

        task__finalize(status, payload, event)

        method_name = "task___#{task['task']}__error"
        if self.respond_to?(method_name)
          __send__ method_name, status, task, error
        end
      end



      # XXX: move task finish handlers into tasks/
      def task___fetch__finish(status, task)
        status['packages'] ||= {}
        status['packages'][task['application']] ||= []

        unless status['packages'][task['application']].include?(task['package'])
          status['packages'][task['application']] << task['package']
        end
      end

      def pkg__remove(status, payload, event)
        status['packages'] ||= {}
        packages = status['packages'][payload['application']]
        packages.delete(payload['package']) if packages
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

      # TODO: XXX: deprecated
      alias fetch_result__remove pkg__remove
    end
  end
end
