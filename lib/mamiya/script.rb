require 'mamiya/dsl'
require 'mamiya/logger'

require 'shellwords'

module Mamiya
  class Script < DSL
    class CommandFailed < Exception; end

    add_hook :before_build
    add_hook :prepare_build
    add_hook :build
    add_hook :after_build

    #add_hook :before_distribute
    #add_hook :after_distribute

    add_hook :before_prepare
    add_hook :prepare
    add_hook :after_prepare

    add_hook :before_switch
    add_hook :release
    add_hook :after_switch

    add_hook :before_rollback
    add_hook :rollback
    add_hook :after_rollback

    add_hook :package_name, chain: true
    add_hook :package_meta, chain: true

    set_default :application, nil
    set_default :repository, nil
    set_default :ref, nil

    set_default :discover_servers, true
    set_default :on_client_failure, :error # error, warn, ignore

    set_default :build_from, nil
    set_default :build_to, nil
    set_default :package_under, nil
    set_default :exclude_from_package, []
    set_default :dereference_symlinks, true

    # TODO: use variable in config.yml
    set_default :deploy_to, nil
    set_default :prepare_to, nil

    set_default :logger, Mamiya::Logger.new(outputs: [])

    set_default :skip_prepare_build, false

    set_default :script_file, nil
    set_default :script_additionals, []

    def run(*args, allow_failure: false)
      # TODO: Stop when fail
      actual = -> do
        logger = self.logger['RUN']

        logger.info("$ #{args.shelljoin}")

        err_r, err_w = IO.pipe
        out_r, out_w = IO.pipe

        pid = spawn(*args, out: out_w, err: err_w)

        [out_w, err_w].each(&:close)

        buf = ""

        ths = {:debug => out_r, :warn => err_r}.map do |severity, io|
          Thread.new {
            until io.eof?
              str = io.gets
              logger.__send__(severity, str.chomp)
              buf << str
            end
          }.tap { |_| _.abort_on_exception = true }
        end

        pid, status = Process.waitpid2(pid)

        begin
          timeout(3) { ths.each(&:join) }
        rescue Timeout::Error
        end
        ths.each { |_| _.alive? && _.kill }

        [out_r, err_r].each(&:close)

        unless allow_failure || status.success?
          raise CommandFailed,
            "Excecution failed (" \
            "status=#{status.exitstatus}" \
            " pid=#{status.pid}" \
            "#{status.signaled? ? "termsig=#{status.termsig.inspect} stopsig=#{status.stopsig.inspect}" : nil}" \
            "#{status.stopped? ? " stopped" : nil}" \
            "): #{args.inspect}"
        end

        buf
      end

      if defined? Bundler
        Bundler.with_clean_env(&actual)
      else
        actual.call
      end
    end

    def cd(*args)
      logger.info "$ cd #{args[0]}"
      Dir.chdir *args
    end

    def deploy_to
      self[:deploy_to] && Pathname.new(self[:deploy_to])
    end

    def release_path
      self[:release_path] && Pathname.new(self[:release_path])
    end

    def shared_path
      deploy_to && deploy_to.join('shared')
    end

    def current_path
      deploy_to && deploy_to.join('current')
    end
  end
end
