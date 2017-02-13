require 'mamiya/agent/tasks/abstract'

module Mamiya
  class Agent
    module Tasks
      class Remove < Abstract
        def run
          release_path = config.deploy_to_for(application).join('releases', package)
          logger.info "Removing package #{package} from releases (app=#{application})"
          begin
            release_path.rmtree
          rescue Errno::ENOENT
          end
        end

        private

        def application
          task['app']
        end

        def package
          task['pkg']
        end
      end
    end
  end
end
