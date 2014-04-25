require 'mamiya/agent/handlers/abstract'

module Mamiya
  class Agent
    module Handlers
      class Fetch < Abstract
        FETCH_ACK_EVENT = 'mamiya:fetch-result:ack'
        FETCH_SUCCESS_EVENT = 'mamiya:fetch-result:success'
        FETCH_ERROR_EVENT = 'mamiya:fetch-result:error'

        def run!
          agent.serf.event(FETCH_ACK_EVENT,
            {
              name: agent.serf.name,
              application: payload['application'],
              package: payload['package']
            }.to_json
          )

          agent.fetcher.enqueue(payload['application'], payload['package']) do |error|
            if error
              agent.serf.event(FETCH_ERROR_EVENT,
                {
                  name: agent.serf.name,
                  application: payload['application'],
                  package: payload['package'],
                  error: error.inspect,
                }.to_json
              )
            else
              agent.serf.event(FETCH_SUCCESS_EVENT,
                {
                  name: agent.serf.name,
                  application: payload['application'],
                  package: payload['package'],
                }.to_json
              )
            end

            agent.update_tags
          end
        end
      end
    end
  end
end
