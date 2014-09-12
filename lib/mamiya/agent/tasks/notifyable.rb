require 'mamiya/agent/tasks/abstract'

module Mamiya
  class Agent
    module Tasks
      class Notifyable < Abstract
        def execute
          agent.trigger('task', action: 'start',
            task: task,
            coalesce: false,
          )

          super

        ensure
          if error
            agent.trigger('task', action: 'error',
              error: error.class.name,
              task: task,
              coalesce: false,
            )
          else
            agent.trigger('task', action: 'finish',
              task: task,
              coalesce: false,
            )
          end
        end
      end
    end
  end
end
