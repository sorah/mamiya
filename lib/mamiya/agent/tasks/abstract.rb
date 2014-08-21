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

        def self.identifier
          self.name.split(/::/).last.gsub(/(.)([A-Z])/, '\1_\2').downcase
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
