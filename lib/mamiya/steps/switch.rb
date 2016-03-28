require 'mamiya/steps/abstract'

module Mamiya
  module Steps
    class Switch < Abstract
      def run!
        @exception = nil
        @switched = false

        if current_targets_release?
          logger.info "Already switched"
        else
          switch
        end

        if @switched ? do_release? : force_release?
          release
        else
          logger.warn "Skipping release"
        end

      rescue Exception => e
        @exception = e
        raise e
      ensure
        logger.warn "Exception occured, cleaning up..." if @exception

        script.after_switch(labels)[@exception] if @switched

        logger.info "DONE!" unless @exception
      end

      def switch
        logger.info "Switching to #{target}"
        @switched = true
        script.before_switch(labels)[]

        next_path = script.release_path.parent.join(script.current_path.basename)
        next_path.make_symlink(target.realpath)
        FileUtils.mv(next_path, script.current_path)
      end

      def release
        # TODO: link with relative if available?
        # TODO: Restore this if FAILED

        old_pwd = Dir.pwd
        Dir.chdir(target)

        logger.info "Releasing..."

        script.release(labels)[@exception]
      ensure
        Dir.chdir old_pwd if old_pwd
      end

      # XXX: dupe with prepare step. modulize?

      # This class see target_dir's script
      alias given_script script 

      # XXX: modulize?
      def script
        @target_script ||= Mamiya::Script.new.load!(
          target.join('.mamiya.script', target_meta['script'])).tap do |script|
          script.set(:deploy_to, config.deploy_to_for(script.application))
          script.set(:release_path, target)
          script.set(:logger, logger)
        end
      end

      private

      def current_targets_release?
        script.current_path.exist? && script.current_path.realpath == target.realpath
      end

      def do_release?
        force_release? ? true : !no_release?
      end

      def force_release?
        !!options[:do_release]
      end

      def no_release?
        !!options[:no_release]
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
