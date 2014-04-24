require 'thread'
require 'mamiya/steps/fetch'

module Mamiya
  class Agent
    ##
    # This class has a queue for fetching packages.
    class Fetcher
      GRACEFUL_TIMEOUT = 60

      def initialize(destination: raise(ArgumentError, 'missing :destination'), logger: Mamiya::Logger.new)
        @thread = nil
        @queue = Queue.new

        @logger = logger['fetcher']
        @destination = destination
      end

      attr_reader :thread

      def enqueue(app, package, &callback)
        @queue << [app, package, callback]
      end

      def start!
        @logger.info 'Starting...'

        @thread = Thread.new(&method(:main_loop))
        @thread.abort_on_exception = true
      end

      def stop!(graceful = false)
        return unless @thread

        if graceful
          @queue << :suicide
          @thread.join(GRACEFUL_TIMEOUT)
        end

        @thread.kill if @thread.alive?
      ensure
        @thread = nil
      end

      def running?
        @thread && @thread.alive?
      end

      private

      def main_loop
        while order = @queue.pop
          break if order == :suicide
          handle_order(*order)
        end
      end

      def handle_order(app, package, callback = nil)
        @logger.info "fetching #{app}:#{package}"

        Mamiya::Steps::Fetch.new(
          application: app,
          package: package,
          destination: @destination,
        ).run!

        callback.call if callback

        @logger.info "fetched #{app}:#{package}"

      rescue Exception => e
        @logger.fatal "fetch failed (#{app}:#{package}): #{e.inspect}"
        e.backtrace.each do |line|
          @logger.fatal line.prepend("\t")
        end

        callback.call(e) if callback
      end
    end
  end
end
