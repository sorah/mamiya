require 'fileutils'

require 'mamiya/agent/tasks/notifyable'
require 'mamiya/steps/fetch'
require 'mamiya/storages/abstract'

module Mamiya
  class Agent
    module Tasks
      class Fetch < Notifyable
        def run
          logger.info "Fetching #{application}/#{package}"

          take_interval
          prepare_destination
          step.run!
          order_cleaning
        rescue Mamiya::Storages::Abstract::AlreadyFetched
          logger.info "It has already fetched; skipping."
        end

        private

        def take_interval
          fetch_sleep = config[:fetch_sleep]
          wait = rand(fetch_sleep)

          @logger.info "Sleeping #{wait} sec before starting fetch"
          rand(wait)
        end

        def prepare_destination
          FileUtils.mkdir_p(destination) unless File.exist?(destination)
        end

        def order_cleaning
          task_queue.enqueue(:clean, {})
        end

        def application
          task['app']
        end

        def package
          task['pkg']
        end

        def destination
          @destination ||= File.join(packages_dir, application)
        end

        def packages_dir
          @packages_dir ||= config && config[:packages_dir]
        end

        def step
          @step ||= Mamiya::Steps::Fetch.new(
            application: application,
            package: package,
            destination: destination,
            config: config,
          )
        end
      end
    end
  end
end
