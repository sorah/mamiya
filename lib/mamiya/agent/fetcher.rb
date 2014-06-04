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
        @worker_thread = nil
        @queueing_thread = nil
        @external_queue = Queue.new
        @internal_queue = Queue.new

        @config = config
        @destination = config[:packages_dir]
        @keep_packages = config[:keep_packages]
        @current_job = nil
        @pending_jobs = []

        @logger = logger['fetcher']
      end

      attr_reader :worker_thread
      attr_reader :queueing_thread
      attr_reader :current_job
      attr_reader :pending_jobs
      attr_writer :cleanup_hook

      def enqueue(app, package, before: nil, &callback)
        @external_queue << [app, package, before, callback]
      end

      def queue_size
        @queue.size
      end

      def start!
        stop!
        @logger.info 'Starting...'

        @worker_thread = Thread.new(&method(:main_loop))
        @worker_thread.abort_on_exception = true

        @queueing_thread = Thread.new(&method(:queueing_loop))
        @queueing_thread.abort_on_exception = true
      end

      def stop!(graceful = false)
        {@external_queue => @queueing_thread, @internal_queue => @worker_thread}.each do |q, th|
          next unless th
          if graceful
            q << :suicide
            th.join(GRACEFUL_TIMEOUT)
          end

          th.kill if th.alive?
        end
      ensure
        @worker_thread = nil
        @queueing_thread = nil
      end

      def running?
        @worker_thread && @worker_thread.alive? && \
        @queueing_thread && @queueing_thread.alive?
      end

      def working?
        !!@current_job
      end

      def cleanup
        Dir[File.join(@destination, '*')].each do |app|
          packages = Dir[File.join(app, "*.tar.gz")]
          packages.sort_by! { |_| [File.mtime(_), _] }
          packages[0...-@keep_packages].each do |victim|
            @logger.info "Cleaning up: remove #{victim}"
            File.unlink(victim) if File.exist?(victim)

            meta_victim = victim.sub(/\.tar\.gz\z/, '.json')
            if File.exist?(meta_victim)
              @logger.info "Cleaning up: remove #{meta_victim}"
              File.unlink(meta_victim)
            end

            package_name = File.basename(victim, '.tar.gz')
            if @cleanup_hook
              @cleanup_hook.call(File.basename(app), package_name)
            end
          end
        end
      end

      private

      def main_loop
        while order = @internal_queue.pop
          break if order == :suicide
          @pending_jobs.delete(order)
          handle_order(*order)
        end
      end

      def queueing_loop
        while order = @external_queue.pop
          break if order == :suicide
          @pending_jobs << order
          @internal_queue << order
        end
      end

      def handle_order(app, package, before_hook = nil, callback = nil)
        @current_job = [app, package]
        @logger.info "fetching #{app}:#{package}"

        if @config[:fetch_sleep]
          wait = rand(@config[:fetch_sleep])
          @logger.debug "Sleeping #{wait} before starting fetch"
          sleep wait
        end

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

        @current_job = nil
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
        @current_job = nil
      end
    end
  end
end
