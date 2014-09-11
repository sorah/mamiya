require 'mamiya/steps/abstract'

module Mamiya
  module Steps
    class Switch < Abstract
      def run!
        @exception = nil
        logger.info "Switching to #{target}"

        script.before_switch(labels)[]

        # TODO: link with relative if available?
        # TODO: Restore this if FAILED
        File.unlink script.current_path if script.current_path.symlink?
        script.current_path.make_symlink(target.realpath)

        if do_release?
          begin
            old_pwd = Dir.pwd
            Dir.chdir(target)

            logger.info "Releasing..."

            script.release(labels)[@exception]
          ensure
            Dir.chdir old_pwd if old_pwd
          end
        else
          logger.warn "Skipping release (:no_release is set)"
        end

      rescue Exception => e
        @exception = e
        raise e
      ensure
        logger.warn "Exception occured, cleaning up..." if @exception

        script.after_switch(labels)[@exception]

        logger.info "DONE!" unless @exception
      end

      # XXX: dupe with prepare step. modulize?

      # This class see target_dir's script
      alias given_script script 

      def script
        @target_script ||= Mamiya::Script.new.load!(
          target.join('.mamiya.script', target_meta['script'])).tap do |script|
          # XXX: release_path is set by options[:target] but deploy_to is set by script?
          script.set(:release_path, target)
          script.set(:logger, logger)
        end
      end

      private

      def do_release?
        !options[:no_release]
      end

      def target
        @target ||= Pathname.new(options[:target]).realpath
      end

      def target_meta
        @target_meta ||= JSON.parse target.join('.mamiya.meta.json').read
      end

      def labels
        # XXX: TODO: is it sure that passing labels via options of step?
        options[:labels]
      end
    end
  end
end
