require 'mamiya/agent'
require 'thread'

module Mamiya
  class Agent
    class TaskQueue
      def initialize(agent, classes={}, logger: Mamiya::Logger.new)
        @external_queue = Queue.new
        @queues = {}
      end

      def start!
      end

      def stop!(graceful = false)
      end

      def running?
      end

      def working?
      end

      def enqueue(task)
      end

      def status
        {
        }
      end

      private

      def main_loop
      end

      def queueing_loop
      end

      def handle_task
      end
    end
  end
end
