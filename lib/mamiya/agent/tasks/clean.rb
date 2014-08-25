require 'mamiya/agent/tasks/abstract'

module Mamiya
  class Agent
    module Tasks
      class Clean < Abstract

        def run
          # TODO: remove fetcher
          victims.each do |app, victim|
            @logger.info "Cleaning up: remove #{victim}"
            File.unlink(victim) if File.exist?(victim)

            meta_victim = victim.sub(/\.tar\.gz\z/, '.json')
            if File.exist?(meta_victim)
              @logger.info "Cleaning up: remove #{meta_victim}"
              File.unlink(meta_victim)
            end

            package_name = File.basename(victim, '.tar.gz')

            # XXX: depends on FS structure
            agent.trigger('pkg', action: 'remove',
              application: app,
              package: package_name,
              coalesce: false,
            )
          end
        end

        def victims
          Dir[File.join(config[:packages_dir], '*')].flat_map do |app|
            packages = Dir[File.join(app, "*.tar.gz")].
              sort_by { |_| [File.mtime(_), _] }

            packages[0...-(config[:keep_packages])].map do |victim|
              [File.basename(app), victim]
            end
          end
        end

      end
    end
  end
end
