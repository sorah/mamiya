require 'thread'
require 'mamiya/steps/fetch'

require 'mamiya/storages/abstract'

module Mamiya
  class Agent
    ##
    # This class has a queue for fetching packages.
    class Fetcher
      GRACEFUL_TIMEOUT = 60

      def initialize(config, logger: Mamiya::Logger.new)
        @thread = nil
        @queue = Queue.new

        @config = config
        @destination = config[:packages_dir]
        @keep_packages = config[:keep_packages]

        @logger = logger['fetcher']
        @working = nil
      end

      attr_reader :thread

      def enqueue(app, package, before: nil, &callback)
        @queue << [app, package, before, callback]
      end

      def queue_size
        @queue.size
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

      def working?
        !!@working
      end

      def cleanup
        Dir[File.join(@destination, '*')].each do |app|
          packages = Dir[File.join(app, "*.tar.gz")]
          packages.sort_by! { |_| [File.mtime(_), _] }
          packages[0...-@keep_packages].each do |victim|
            @logger.info "Cleaning up: remove #{victim}"
            File.unlink victim

            meta_victim = victim.sub(/\.tar\.gz\z/, '.json')
            if victim
              @logger.info "Cleaning up: remove #{meta_victim}"
              File.unlink(meta_victim)
            end
          end
        end
      end

      private

      def main_loop
        while order = @queue.pop
          break if order == :suicide
          handle_order(*order)
        end
      end

      def handle_order(app, package, before_hook = nil, callback = nil)
        @working = true
        @logger.info "fetching #{app}:#{package}"
        # TODO: Limit apps by configuration

        destination = File.join(@destination, app)

        Dir.mkdir(destination) unless File.exist?(destination)

        before_hook.call if before_hook

        # TODO: before run hook for agent.update_tags!
        Mamiya::Steps::Fetch.new(
          application: app,
          package: package,
          destination: destination,
          config: @config,
        ).run!

        callback.call if callback

        @logger.info "fetched #{app}:#{package}"

        cleanup

      rescue Mamiya::Storages::Abstract::AlreadyFetched => e
        @logger.info "skipped #{app}:#{package} (already fetched)"
        callback.call(e) if callback
      rescue Exception => e
        @logger.fatal "fetch failed (#{app}:#{package}): #{e.inspect}"
        e.backtrace.each do |line|
          @logger.fatal "\t#{line}"
        end

        callback.call(e) if callback
      ensure
        @working = false
      end
    end
  end
end
