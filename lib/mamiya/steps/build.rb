require 'mamiya/steps/abstract'
require 'mamiya/package'

module Mamiya
  module Steps
    class Build < Abstract
      def run!
        logger.info "Initiating package build"

        logger.info "Running script.before_build"
        script.before_build[]

        unless script.skip_prepare_build
          logger.info "Running script.prepare_build"
          script.prepare_build[File.exists?(script.build_from)]
        else
          logger.debug "prepare_build skipped due to script.skip_prepare_build"
        end

        old_pwd = Dir.pwd
        begin
          # Using without block because chdir in block shows warning
          Dir.chdir(script.build_from)
          logger.info "Running script.build ..."
          logger.debug "pwd=#{Dir.pwd}"
          script.build[]
        ensure
          Dir.chdir old_pwd
        end


        logger.debug "Determining package name..."
        package_name = Dir.chdir(script.build_from) {
          script.package_name[
            [Time.now.strftime("%Y-%m-%d_%H.%M.%S"), script.application]
          ].join('-')
        }
        logger.info "Package name determined: #{package_name}"

        package_path = File.join(script.build_to, package_name)
        package = Mamiya::Package.new(package_path)
        package.meta[:application] = script.application

        Dir.chdir(script.build_from) do
          package.meta.replace script.package_meta[package.meta]
        end

        logger.info "Packaging to: #{package.path}"
        logger.debug "meta=#{package.meta.inspect}"
        package.build!(script.build_from,
           exclude_from_package: script.exclude_from_package || [],
           dereference_symlinks: script.dereference_symlinks || false,
           package_under: script.package_under || nil,
           logger: logger)
        logger.info "Packed."

        logger.info "Running script.after_build"
        script.after_build[]

        logger.info "DONE!"
      end
    end
  end
end
