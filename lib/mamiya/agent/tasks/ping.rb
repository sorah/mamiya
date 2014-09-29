require 'mamiya/agent'
require 'mamiya/agent/tasks/abstract'

module Mamiya
  class Agent
    module Tasks
      class Ping < Abstract
        def run
          logger.info "Responding ping: #{task.inspect}"

          agent.trigger('pong', coalesce: false,
            at: Time.now.to_i,
            id: self.task_id,
          )
        end
      end
    end
  end
end
