require 'mamiya/agent'
require 'mamiya/logger'

module Mamiya
  class Agent
    module Tasks
      class Abstract
        def initialize(task_queue, task, agent: nil, logger: Mamiya::Logger.new)
          @agent = agent
          @logger = logger
          @queue = task_queue
          @task = task
          @error = nil
        end

        attr_reader :task, :error, :logger, :agent

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
