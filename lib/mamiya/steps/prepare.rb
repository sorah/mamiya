require 'mamiya'
require 'mamiya/steps/abstract'

require 'pathname'
require 'json'

module Mamiya
  module Steps
    class Prepare < Abstract
      def run!
        @exception = nil
        Mamiya.chdir(target) do
          logger.info "Preparing #{target}..."

          script.before_prepare(labels)[]
          script.prepare(labels)[]

          File.write target.join('.mamiya.prepared'), "#{Time.now.to_i}\n"
        end
      rescue Exception => e
        @exception = e
        raise e
      ensure
        logger.warn "Exception occured, cleaning up..." if @exception

        script.after_prepare(labels)[@exception]

        logger.info "DONE!" unless @exception
      end

      # This class see target_dir's script
      alias given_script script 

      def script
        @target_script ||= Mamiya::Script.new.load!(
          target.join('.mamiya.script', target_meta['script'])).tap do |script|
          script.set(:deploy_to, config.deploy_to_for(script.application))
          script.set(:release_path, target)
          script.set(:logger, logger)
        end
      end

      private

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
