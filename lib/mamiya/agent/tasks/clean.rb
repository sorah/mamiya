require 'mamiya/agent/tasks/abstract'

module Mamiya
  class Agent
    module Tasks
      class Clean < Abstract

        def run
          # XXX:
          clean_packages
          clean_prereleases
        end

        def clean_packages
          package_victims.each do |app, victim|
            @logger.info "Cleaning package: remove #{victim}"
            File.unlink(victim) if File.exist?(victim)

            meta_victim = victim.sub(/\.tar\.gz\z/, '.json')
            if File.exist?(meta_victim)
              @logger.info "Cleaning up: remove #{meta_victim}"
              File.unlink(meta_victim)
            end

            # XXX: depends on FS structure
            package_name = File.basename(victim, '.tar.gz')

            # XXX: TODO: application->app, package->pkg
            agent.trigger('pkg', action: 'remove',
              application: app,
              package: package_name,
              coalesce: false,
            )
          end
        end

        def package_victims
          Dir[File.join(config[:packages_dir], '*')].flat_map do |app|
            packages = Dir[File.join(app, "*.tar.gz")].
              sort_by { |_| [File.mtime(_), _] }

            packages[0...-(config[:keep_packages])].map do |victim|
              [File.basename(app), victim]
            end
          end
        end

        def clean_prereleases
          prerelease_victims.each do |app, victim|
            @logger.info "Cleaning prerelease: remove #{victim}"
            package_name = File.basename(victim)
            FileUtils.remove_entry_secure victim

            agent.trigger('prerelease', action: 'remove',
              app: app,
              pkg: package_name,
              coalesce: false,
            )
          end
        end

        def prerelease_victims
          Dir[File.join(config[:prereleases_dir], '*')].flat_map do |app|
            prereleases = Dir[File.join(app, "*")].
              sort_by { |_| [File.mtime(_), _] }

            prereleases[0...-(config[:keep_prereleases])].map do |victim|
              [File.basename(app), victim]
            end
          end
        end

      end
    end
  end
end
