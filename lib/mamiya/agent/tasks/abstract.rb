require 'mamiya/agent'

module Mamiya
  class Agent
    module Tasks
      class Abstract
        def initialize(task_queue, task)
          @queue = task_queue
          @task = task
        end

        attr_reader :task

        def before
        end

        def run
        end

        def after
        end

        def errored
        end
      end
    end
  end
end
