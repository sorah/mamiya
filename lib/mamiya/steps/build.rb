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

        unless script_file
          raise ScriptFileNotSpecified, "Set script files to :script_file"
        end

        unless script.application
          raise ApplicationNotSpecified, ":application should be specified in your script file"
        end

        run_before_build
        run_prepare_build
        run_build

        # XXX: Is this really suitable here? Package class should do?
        copy_deploy_scripts

        set_metadata

        build_package

        logger.info "Packed."

      rescue Exception => e
        @exception = e
        raise
      ensure
        logger.warn "Exception occured, cleaning up..." if @exception

        if script_dest.exist?
          FileUtils.remove_entry_secure script_dest
        end

        logger.info "Running script.after_build"
        script.after_build[@exception]

        unless @exception
          logger.info "DONE: #{package_name} built at #{package.path}"
          return package_name
        end
      end

      private

      def run_before_build
        logger.info "Running script.before_build"
        script.before_build[]
      end

      def run_prepare_build
        unless script.skip_prepare_build
          logger.info "Running script.prepare_build"
          script.prepare_build[File.exists?(script.build_from)]
        else
          logger.debug "prepare_build skipped due to script.skip_prepare_build"
        end
      end

      def run_build
        old_pwd = Dir.pwd
        begin
          # Using without block because chdir in block shows warning
          Dir.chdir(script.build_from)
          logger.info "Running script.build"
          logger.debug "pwd=#{Dir.pwd}"
          script.build[]
        ensure
          Dir.chdir old_pwd
        end
      end

      def copy_deploy_scripts
        # XXX: TODO: move to another class?
        logger.info "Copying script files"

        if script_dest.exist?
          logger.warn "Removing existing .mamiya.script"
          FileUtils.remove_entry_secure script_dest
        end
        script_dest.mkdir

        logger.debug "- #{script_file} -> #{script_dest}"
        FileUtils.cp script_file, script_dest

        if script.script_additionals
          script_dir = Pathname.new(File.dirname(script_file))
          script.script_additionals.each do |additional|
            src = script_dir.join(additional)
            dst = script_dest.join(additional)
            logger.debug "- #{src} -> #{dst}"
            FileUtils.mkdir_p dst.dirname
            FileUtils.cp_r src, dst
          end
        end
      end

      def set_metadata
        package.meta[:application] = script.application
        package.meta[:script] = File.basename(script_file)
        Dir.chdir(script.build_from) do
          package.meta.replace script.package_meta[package.meta]
        end
      end

      def build_package
        logger.debug "Packaging to: #{package.path}"
        logger.debug "meta=#{package.meta.inspect}"
        package.build!(script.build_from,
           exclude_from_package: script.exclude_from_package || [],
           dereference_symlinks: script.dereference_symlinks || false,
           package_under: script.package_under || nil,
           logger: logger)
      end

      def package_name
        @package_name ||= begin
          logger.debug "Determining package name..."
          name = Dir.chdir(script.build_from) {
            script.package_name[
              [Time.now.strftime("%Y%m%d%H%M%S"), script.application]
            ].join('-')
          }
          logger.debug "Package name determined: #{name}"
          name
        end
      end

      def package_path
        @package_path ||= File.join(script.build_to, package_name)
      end

      def package
        @package ||= Mamiya::Package.new(package_path)
      end

      def script_file
        @script_file ||= script.script_file || script._file
      end

      def script_dest
        @script_dest ||= if script.package_under
          Pathname.new File.join(script.build_from, script.package_under, '.mamiya.script')
        else
          Pathname.new File.join(script.build_from, '.mamiya.script')
        end
      end
    end
  end
end
