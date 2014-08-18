require 'mamiya/agent'

module Mamiya
  class Agent
    module Tasks
      class Abstract
        def initialize(task_queue, task)
          @queue = task_queue
          @task = task
          @error = nil
        end

        attr_reader :task, :error

        def execute
          before
          run
        rescue Exception => error
          @error = error
        ensure
          after
        end

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
