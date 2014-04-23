require 'json'

module Mamiya
  class Agent
    module Handlers
      class Abstract
        def initialize(agent, event)
          @agent = agent
          @event = event
          @payload = (event.payload && !event.payload.empty?) ? JSON.parse(event.payload) : {}
        end

        attr_reader :agent, :event, :payload

        def run!
        end
      end
    end
  end
end
