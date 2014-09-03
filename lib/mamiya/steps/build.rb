require 'mamiya/steps/abstract'
require 'mamiya/package'

require 'fileutils'

module Mamiya
  module Steps
    class Build < Abstract
      class ScriptFileNotSpecified < Exception; end
      class ApplicationNotSpecified < Exception; end

      def run!
        @exception = nil

        script_file = script.script_file || script._file

        unless script_file
          raise ScriptFileNotSpecified, "Set script files to :script_file"
        end

        unless script.application
          raise ApplicationNotSpecified, ":application should be specified in your script file"
        end

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

        logger.info "Copying script files..."
        script_dest = Pathname.new File.join(script.build_from, '.mamiya.script')
        if script_dest.exist?
          logger.warn "Removing existing .mamiya.script"
          FileUtils.remove_entry_secure script_dest
        end
        script_dest.mkdir

        logger.info "- #{script_file} -> .mamiya.script/"
        FileUtils.cp script_file, script_dest

        if script.script_additionals
          script_dir = Pathname.new(File.dirname(script_file))
          script.script_additionals.each do |additional|
            src = script_dir.join(additional)
            dst = script_dest.join(additional)
            logger.info "- #{src} -> #{dst}"
            FileUtils.cp_r src, dst
          end
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
        package.meta[:script] = File.basename(script_file)

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

      rescue Exception => e
        @exception = e
        raise
      ensure
        logger.warn "Exception occured, cleaning up..." if @exception

        if script_dest && File.exist?(script_dest)
          FileUtils.remove_entry_secure script_dest
        end

        logger.info "Running script.after_build"
        script.after_build[@exception]

        logger.info "DONE!" unless @exception
      end
    end
  end
end
