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

    set_default :logger, Mamiya::Logger.new(outputs: [])

    set_default :skip_prepare_build, false

    set_default :script_file, nil
    set_default :script_additionals, []

    def run(*args, allow_failure: false)
      # TODO: Stop when fail
      actual = -> do
        started_at = Time.now
        run_id = generate_run_id()
        logger = self.logger["run:#{run_id}"]

        env = args.last.is_a?(Hash) ? args.pop : {}
        shellenv = env.empty? ? nil : "#{escape_env(env)} "

        logger.info("$ #{shellenv}#{args.shelljoin}")

        err_r, err_w = IO.pipe
        out_r, out_w = IO.pipe

        pid = spawn(env, *args.map(&:to_s), out: out_w, err: err_w)

        [out_w, err_w].each(&:close)

        buf = ""
        last_out = Time.now

        ths = {:info => out_r, :warn => err_r}.map do |severity, io|
          Thread.new {
            until io.eof?
              str = io.gets
              logger.__send__(severity, "  #{str.chomp}")
              buf << str
              last_out = Time.now
            end
          }.tap { |_| _.abort_on_exception = true }
        end

        timekeeper_th = Thread.new do
          l = logger['timekeeper']
          loop do
            if 90 < (Time.now - last_out)
              l.warn "! pid #{pid} still running; since #{started_at}"
            end
            sleep 60
          end
        end
        timekeeper_th.abort_on_exception = true

        pid, status = Process.waitpid2(pid)
        timekeeper_th.kill if timekeeper_th.alive?

        begin
          Timeout.timeout(3) { ths.each(&:join) }
        rescue Timeout::Error
        end
        ths.each { |_| _.alive? && _.kill }

        [out_r, err_r].each(&:close)

        unless allow_failure || status.success?
          failure_msg = "Execution failed (" \
            "status=#{status.exitstatus}" \
            " pid=#{status.pid}" \
            "#{status.signaled? ? "termsig=#{status.termsig.inspect} stopsig=#{status.stopsig.inspect}" : nil}" \
            "#{status.stopped? ? " stopped" : nil}" \
            "): #{args.inspect}"

          logger.error failure_msg
          raise CommandFailed, failure_msg

        end

        logger.info "* pid #{pid} completed: #{args.inspect}"

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

    def build_from
      self[:build_from] && Pathname.new(self[:build_from])
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

    private

    RUN_ID_BASE_TIME = Time.new(2014,01,01,0,0,0).to_i
    def generate_run_id
      (@run_id_mutex ||= Mutex.new).synchronize do
        t = Time.now.to_i
        id = (t - RUN_ID_BASE_TIME).to_i.to_s(36)

        @last_run_id_time ||= 0
        if (t - @last_run_id_time) < 1
          @run_id_seq ||= 0
          @run_id_seq += 1
          id << @run_id_seq.to_s(36)
        else
          @run_id_seq = nil
          id << '0'
        end

        @last_run_id_time = t
        id
      end
    end

    def escape_env(hash)
      hash.map { |key, value|
        [key.to_s.shellescape, value.to_s.shellescape].join("=")
      }.join(" ")
    end
  end
end
