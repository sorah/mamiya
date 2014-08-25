require 'mamiya/agent/handlers/abstract'

module Mamiya
  class Agent
    module Handlers
      class Task < Abstract
        def run!
          agent.task_queue.enqueue(payload['task'].to_sym, payload)
        end
      end
    end
  end
end
