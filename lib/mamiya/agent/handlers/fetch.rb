require 'mamiya/agent/handlers/abstract'
require 'mamiya/storages/abstract'

module Mamiya
  class Agent
    module Handlers
      class Fetch < Abstract
        FETCH_ACK_EVENT = 'mamiya:fetch-result:ack'
        FETCH_START_EVENT = 'mamiya:fetch-result:start'
        FETCH_SUCCESS_EVENT = 'mamiya:fetch-result:success'
        FETCH_ERROR_EVENT = 'mamiya:fetch-result:error'

        IGNORED_ERRORS = [
          Mamiya::Storages::Abstract::AlreadyFetched.new(''),
        ].freeze

        def run!
          agent.serf.event(FETCH_ACK_EVENT,
            {
              name: agent.serf.name,
              application: payload['application'],
              package: payload['package'],
              pending: agent.fetcher.queue_size.succ,
            }.to_json
          )

          agent.fetcher.enqueue(
            payload['application'], payload['package'],
            before: proc {
              agent.serf.event(FETCH_START_EVENT,
                {
                  name: agent.serf.name,
                  application: payload['application'],
                  package: payload['package'],
                  pending: agent.fetcher.queue_size.succ,
                }.to_json
              )
              agent.update_tags!
            }
          ) do |error|
            if error && IGNORED_ERRORS.lazy.grep(error.class).none?
              # FIXME: TODO: may exceed 256
              begin
                agent.serf.event(FETCH_ERROR_EVENT,
                  {
                    name: agent.serf.name,
                    application: payload['application'],
                    package: payload['package'],
                    error: error.class,
                    pending: agent.fetcher.queue_size,
                  }.to_json
                )
              rescue Villein::Client::SerfError => e
                agent.logger.error "error sending fetch error event: #{e.inspect}"
              end
            else
              agent.serf.event(FETCH_SUCCESS_EVENT,
                {
                  name: agent.serf.name,
                  application: payload['application'],
                  package: payload['package'],
                  pending: agent.fetcher.queue_size,
                }.to_json
              )
            end

            agent.update_tags!
          end
        end
      end
    end
  end
end
