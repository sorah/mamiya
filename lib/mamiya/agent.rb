require 'thread'
require 'villein'
require 'mamiya/version'

require 'mamiya/util/label_matcher'

require 'mamiya/logger'

require 'mamiya/steps/fetch'
require 'mamiya/steps/prepare'
require 'mamiya/steps/extract'
require 'mamiya/agent/task_queue'

require 'mamiya/agent/tasks/fetch'
require 'mamiya/agent/tasks/prepare'
require 'mamiya/agent/tasks/clean'
require 'mamiya/agent/tasks/switch'
require 'mamiya/agent/tasks/remove'
require 'mamiya/agent/tasks/ping'

require 'mamiya/agent/handlers/task'
require 'mamiya/agent/actions'

require 'sigdump/setup' unless ENV['DISABLE_SIGDUMP'] == '1'

module Mamiya
  class Agent
    include Mamiya::Agent::Actions

    def initialize(config, logger: Mamiya::Logger.new, events_only: nil)
      @config = config
      @serf = init_serf
      @trigger_lock = Mutex.new
      @events_only = events_only

      @terminate = false

      @logger = logger['agent']
    end

    attr_reader :config, :serf, :logger

    def task_queue
      @task_queue ||= Mamiya::Agent::TaskQueue.new(self, logger: logger, task_classes: [
        Mamiya::Agent::Tasks::Fetch,
        Mamiya::Agent::Tasks::Prepare,
        Mamiya::Agent::Tasks::Clean,
        Mamiya::Agent::Tasks::Switch,
        Mamiya::Agent::Tasks::Remove,
        Mamiya::Agent::Tasks::Ping,
      ])
    end

    def run!
      logger.info "Starting..."
      start()
      logger.info "Started."

      loop do
        if @terminate
          terminate
          return
        end
        sleep 1
      end
    end

    def stop!
      @terminate = true
    end

    def start
      serf_start
      task_queue_start
    end

    def terminate
      serf.stop!
      task_queue.stop!
    ensure
      @terminate = false
    end

    ##
    # Returns agent status. Used for HTTP API and `serf query` inspection.
    def status(packages: true)
      # When changing signature, don't forget to change samely of Master#status too
      {}.tap do |s|
        s[:name] = serf.name
        s[:version] = Mamiya::VERSION
        s[:labels] = labels

        s[:queues] = task_queue.status

        if packages
          s[:packages] = self.existing_packages
          s[:prereleases] = self.existing_prereleases
          s[:releases] = self.releases
          s[:currents] = self.currents
        end
      end
    end

    def labels
      config.labels[[]]
    end

    include Mamiya::Util::LabelMatcher

    ##
    # Returns hash with existing packages (where valid) by app name.
    # Packages which has json and tarball is considered as valid.
    def existing_packages
      paths_by_app = Dir[File.join(config[:packages_dir], '*', '*.{tar.gz,json}')].group_by { |path|
        path.split(File::SEPARATOR)[-2]
      }

      Hash[
        paths_by_app.map { |app, paths|
          names_by_base = paths.group_by do |path|
            File.basename(path).sub(/\.(?:tar\.gz|json)\z/, '')
          end

          packages = names_by_base.flat_map { |base, names|
            names.map do |name|
              (
                name.end_with?(".tar.gz") &&
                names.find { |_| _.end_with?(".json") } &&
                base
              ) || nil
            end
          }.compact

          [app, packages.sort]
        }
      ]
    end

    def existing_prereleases
      paths_by_app = Dir[File.join(config[:prereleases_dir], '*', '*')].group_by { |path|
        path.split(File::SEPARATOR)[-2]
      }

      Hash[
        paths_by_app.map { |app, paths|
          [
            app,
            paths.select { |path|
              File.exist? File.join(path, '.mamiya.prepared')
            }.map { |path|
              File.basename(path)
            }.sort
          ]
        }
      ]
    end

    def releases
      Hash[config.applications.map do |name, app|
        deploy_to = Pathname.new(app[:deploy_to])
        releases = deploy_to.join('releases')
        next [name, []] unless releases.exist?

        [
          name,
          releases.children.map do |release|
            release.basename.to_s
          end.sort
        ]
      end.compact]
    end

    def currents
      # TODO: when the target is in outside?
      Hash[config.applications.map do |name, app|
        deploy_to = Pathname.new(app[:deploy_to])
        current = deploy_to.join('current')
        next unless current.exist?

        [
          name,
          current.realpath.basename.to_s
        ]
      end.compact]
    end

    def trigger(type, action: nil, coalesce: true, **payload)
      name = "mamiya:#{type}"
      name << ":#{action}" if action

      payload_str = payload.merge(name: self.serf.name).to_json

      @trigger_lock.synchronize do
        logger.debug "Send serf event #{name}(coalesce=#{coalesce}): #{payload_str}"
        serf.event(name, payload_str, coalesce: coalesce)
      end
    end

    private

    def init_serf
      agent_config = (config[:serf] && config[:serf][:agent]) || {}
      # agent_config.merge!(log: $stderr)
      Villein::Agent.new(**agent_config).tap do |serf|
        serf.on_user_event do |event|
          user_event_handler(event)
        end

        serf.respond('mamiya:status') do |event|
          self.status(packages: false).to_json
        end

        serf.respond('mamiya:packages') do |event|
          {
            'packages' => self.existing_packages,
            'prereleases' => self.existing_prereleases,
            'releases' => self.releases,
            'currents' => self.currents,
          }.to_json
        end
      end
    end

    def serf_start
      logger.debug "Starting serf"

      @serf.start!
      @serf.auto_stop
      @serf.wait_for_ready

      logger.debug "Serf became ready"
    end

    def task_queue_start
      logger.debug "Starting task_queue"
      task_queue.start!
    end

    def user_event_handler(event)
      user_event, payload = event.user_event, JSON.parse(event.payload)

      return unless user_event.start_with?('mamiya:')
      user_event = user_event.sub(/^mamiya:/, '')

      type, action = user_event.split(/:/, 2)

      return if @events_only && !@events_only.any?{ |_| _ === type }

      class_name = type.capitalize.gsub(/-./) { |_| _[1].upcase }

      if config.debug_all_events
        logger.debug "Received user event #{type}"
        logger.debug payload.inspect
      end

      if Handlers.const_defined?(class_name)
        handler = Handlers.const_get(class_name).new(self, event)
        meth = action || :run!
        if handler.respond_to?(meth)
          handler.send meth
        else
          if config.debug_all_events
            logger.debug "Handler #{class_name} doesn't respond to #{meth}, skipping"
          end
        end
      else
        #logger.warn("Discarded event[#{event.user_event}] because we don't handle it")
      end
    rescue Exception => e
      logger.fatal("Error during handling event: #{e.inspect}")
      e.backtrace.each do |line|
        logger.fatal line.prepend("\t")
      end

      raise e if $0.end_with?('rspec')
    rescue JSON::ParserError
      logger.warn("Discarded event[#{event.user_event}] with invalid payload (unable to parse as json)")
    end
  end
end
