require 'fileutils'

require 'mamiya/agent/tasks/notifyable'
require 'mamiya/steps/extract'
require 'mamiya/steps/prepare'

module Mamiya
  class Agent
    module Tasks
      class Prepare < Notifyable
        def execute
          return unless check
          super
        end

        def check
          unless package_path.exist?
            new_chain = ['prepare'] + (task['_chain'] || [])
            logger.info "Package not fetched, enqueueing fetch task with #{new_chain.inspect}"
            task_queue.enqueue(
              :fetch,
              task.merge('_chain' => new_chain)
            )
            return false
          end

          true
        end

        def run
          if prerelease_path.exist? 
            if prerelease_path.join('.mamiya.prepared').exist?
              return
            else
              FileUtils.remove_entry_secure prerelease_path
            end
          end

          packages_dir.join(application).mkpath
          prereleases_dir.join(application).mkpath

          extract_step.run!
          prepare_step.run!
        end

        private

        def application
          task['app']
        end

        def package
          task['pkg']
        end

        def release_name
          task['release'] || package
        end

        def packages_dir
          @packages_dir ||= config.packages_dir
        end

        def prereleases_dir
          @prereleases_dir ||= config.prereleases_dir
        end

        def package_path
          packages_dir.join(application, "#{package}.tar.gz")
        end

        def prerelease_path
          prereleases_dir.join(application, release_name)
        end


        def labels
          @labels ||= agent.labels
        end


        def extract_step
          @extract_step ||= Mamiya::Steps::Extract.new(
            package: package_path,
            destination: prerelease_path,
            config: config,
            logger: logger,
          )
        end

        def prepare_step
          @prepare_step ||= Mamiya::Steps::Prepare.new(
            script: nil,
            target: prerelease_path,
            config: config,
            labels: labels,
            logger: logger,
          )
        end
      end
    end
  end
end
