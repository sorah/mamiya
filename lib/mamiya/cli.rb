require 'mamiya'

require 'mamiya/configuration'
require 'mamiya/script'
require 'mamiya/logger'

require 'mamiya/steps/build'
require 'mamiya/steps/push'

require 'mamiya/steps/fetch'
require 'mamiya/steps/extract'
require 'mamiya/steps/prepare'
require 'mamiya/steps/switch'

require 'mamiya/agent'
require 'mamiya/master'

require 'thor'
require 'thread'

module Mamiya
  class CLI < Thor
    class_option :config, aliases: '-C', type: :string
    class_option :script, aliases: '-S', type: :string
    class_option :application, aliases: %w(-a --app), type: :string
    class_option :debug, aliases: %w(-d), type: :boolean
    class_option :color, type: :boolean
    class_option :no_color, type: :boolean
    # TODO: class_option :set, aliases: '-s', type: :array

    no_commands do
      def invoke_command(*)
        super
      rescue SystemExit
        raise
      rescue Exception => e
        logger.fatal "#{e.class}: #{e.message}"

        use_fatal = config(:no_error) && config[:show_backtrace_in_fatal]
        e.backtrace.map{ |_| _.prepend("\t") }.each do |line|
          if use_fatal
            logger.fatal line
          else
            logger.debug line
          end
        end
      end
    end

    desc "list-packages", "List packages in storage"
    method_option :name_only, aliases: '-n'
    def list_packages
      unless options[:name_only]
        puts "Available packages in #{application}:"
        puts ""
      end

      puts storage.packages.sort
    end

    desc "list-applications", "List applications in storage"
    def list_applications
      puts _applications.keys
    end

    desc "show PACKAGE", "Show package"
    method_option :format, aliases: %w(-f), type: :string, default: 'pp'
    def show(package)
      meta = storage.meta(package)

      case options[:format]
      when 'pp'
        require 'pp'
        pp meta
      when 'json'
        require 'json'
        puts meta.to_json
      when 'yaml'
        require 'yaml'
        puts meta.to_yaml
      end
    end

    # ---

    desc "build", "Build package."
    method_option :build_from, aliases: %w(--source -f), type: :string
    method_option :build_to, aliases: %w(--destination -t), type: :string
    method_option :skip_prepare_build, aliases: %w(--no-prepare-build -P), type: :boolean
    method_option :force_prepare_build, aliases: %w(--prepare-build -p), type: :boolean
    method_option :push, aliases: %w(--push), type: :boolean
    def build
      # TODO: overriding name
      %i(build_from build_to).each { |k| script.set(k, File.expand_path(options[k])) if options[k] }

      if options[:force_prepare_build] && options[:skip_prepare_build]
        logger.warn 'Both force_prepare_build and skip_prepare_build are enabled. ' \
          'This results skipping prepare_build...'
      end

      if options[:force_prepare_build]
        script.set :skip_prepare_build, false
      end

      if options[:skip_prepare_build]
        script.set :skip_prepare_build, true
      end

      builder = Mamiya::Steps::Build.new(script: script, logger: logger)
      builder.run!

      if options[:push]
        package = builder.built_package
        push(package.name)
      end
    end

    desc "push PACKAGE", "Upload built packages to storage."
    def push(package_atom)
      package_path = package_path_from_atom(package_atom)

      if options[:application]
        logger.warn "Overriding package's application name with given one: #{options[:application]}"
        sleep 2
      end

      Mamiya::Steps::Push.new(
        config: config,
        package: package_path,
        application: options[:application],
      ).run!
    end

    desc "prune NUMS_TO_KEEP", "Delete old packages, but keep last $NUMS_TO_KEEP packages"
    def prune(nums_to_keep)
      puts "Pruning packages from #{application} (keeping last #{nums_to_keep.to_i} packages)..."

      removed = storage.prune(nums_to_keep.to_i)

      puts "Pruned #{removed.size} packages:"
      puts removed.join(?\n)
    end

    desc "fetch PACKAGE DESTINATION", "Retrieve package from storage"
    def fetch(package_atom, destination)
      Mamiya::Steps::Fetch.new(
        script: script(:no_error),
        config: config,
        package: package_atom,
        application: application,
        destination: destination,
      ).run!
    end

    desc "extract PACKAGE DESTINATION", "Unpack package to DESTINATION"
    def extract(package_atom, destination)
      package_path = package_path_from_atom(package_atom)

      Mamiya::Steps::Extract.new(
        package: package_path,
        destination: destination
      ).run!
    end

    desc "distribute PACKAGE", "Order clients to download specified package."
    def distribute
    end

    desc "prepare TARGET", "Prepare package."
    method_option :labels, type: :string
    def prepare(target)
      Mamiya::Steps::Prepare.new(
        script: nil,
        config: config,
        target: target,
        labels: labels,
      ).run!
    end

    desc "switch TARGET", "Switch current dir then release."
    method_option :no_release, type: :boolean, default: false
    method_option :labels, type: :string
    def switch(target)
      Mamiya::Steps::Switch.new(
        script: nil,
        config: config,
        target: target,
        labels: labels,
        no_release: options[:no_release],
      ).run!
    end

    # ---

    desc "agent", "Start agent."
    method_option :serf, type: :array
    method_option :daemonize, aliases: '-D', type: :boolean, default: false
    method_option :log, aliases: '-l', type: :string
    method_option :pidfile, aliases: '-p', type: :string
    method_option :labels, type: :array
    def agent
      prepare_agent_behavior!
      merge_serf_option!
      override_labels!

      @agent = Agent.new(config, logger: logger)
      @agent.run!
    end

    desc "master", "Start master"
    method_option :serf, type: :array
    method_option :daemonize, aliases: '-D', type: :boolean, default: false
    method_option :log, aliases: '-l', type: :string
    method_option :pidfile, aliases: '-p', type: :string
    def master
      prepare_agent_behavior!
      merge_serf_option!

      @agent = Master.new(config, logger: logger)
      @agent.run!
    end

    private

    def prepare_agent_behavior!
      pidfile = File.expand_path(options[:pidfile]) if options[:pidfile]
      logger # insitantiate

      Process.daemon(:nochdir) if options[:daemonize]

      if pidfile
        open(pidfile, 'w') { |io| io.puts $$ }
        at_exit { File.unlink(pidfile) if File.exist?(pidfile) }
      end

      trap(:HUP) do
        logger.reopen
      end

      trap(:TERM) do
        puts "Received SIGTERM..."
        @agent.stop! if @agent
      end
    end

    def config(dont_raise_error = false)
      return @config if @config
      path = [options[:config], './mamiya.conf.rb', './config.rb', '/etc/mamiya/config.rb'].compact.find { |_| File.exists?(_) }

      if path
        logger.debug "Using configuration: #{path}"
        @config = Mamiya::Configuration.new.load!(File.expand_path(path))
      else
        logger.debug "Couldn't find configuration file"
        return nil if dont_raise_error
        fatal! "Configuration File not found (try --config(-C) option or place it at ./config.rb)"
      end
    end

    def script(dont_raise_error = false)
      return @script if @script
      path = [options[:script], './mamiya.rb', './deploy.rb'].compact.find { |_| File.exists?(_) }

      if path
        logger.debug "Using deploy script: #{path}"
        @script = Mamiya::Script.new.load!(File.expand_path(path)).tap do |s|
          s.set :application, options[:application] if options[:application]
          s.set :logger, logger
        end
      else
        logger.debug "Couldn't find deploy script."
        return nil if dont_raise_error
        fatal! "Deploy Script File not found (try --script(-S) option or place it at ./mamiya.rb or ./deploy.rb)"
      end
    end

    def labels
      c = config(:no_error)
      options[:labels] ? options[:labels].split(/,/).map(&:to_sym) : (c ? c.labels[[]] : [])
    end

    def fatal!(message)
      logger.fatal message
      exit 1
    end

    def merge_serf_option!
      (config[:serf] ||= {})[:agent] ||= {}

      if options[:serf]
        options[:serf].flat_map{ |_| _.split(/,/) }.each do |conf|
          k,v = conf.split(/=/,2)
          config[:serf][:agent][k.to_sym] = v
        end
      end
    end

    def override_labels!
      return unless config(:no_error)
      return unless options[:labels]

      labels = options[:labels].flat_map{ |_| _.split(/,/) }.map(&:to_sym)
      return if labels.empty?

      config.labels do
        labels
      end

      logger.info "Overriding labels: #{labels.inspect}"
    end

    def application
      @_application ||=
        options[:application] \
        || ENV['MAMIYA_APP'] \
        || ENV['MAMIYA_APPLICATION'] \
        || config[:application] \
        || script.application
    end

    def storage
      config.storage_class.new(
        config[:storage].merge(
          application: application
        )
      )
    end

    def _applications
      config.storage_class.find(config[:storage])
    end

    def logger
      @logger ||= begin
        $stdout.sync = ENV["MAMIYA_SYNC_OUT"] == '1'
        outs = [$stdout]
        outs << File.expand_path(options[:log]) if options[:log]
        Mamiya::Logger.new(
          color: options[:no_color] ? false : (options[:color] ? true : nil),
          outputs: outs,
          level: options[:debug] ? Mamiya::Logger::DEBUG : Mamiya::Logger.defaults[:level],
        )
      end
    end

    def package_path_from_atom(package_atom)
      candidates = [
        package_atom,
        options[:build_to] && File.join(options[:build_to], package_atom),
        options[:build_to] && File.join(options[:build_to], "#{package_atom}.tar.gz"),
        script(:no_error) && script.build_to && File.join(script.build_to, package_atom),
        script(:no_error) && script.build_to && File.join(script.build_to, "#{package_atom}.tar.gz"),
      ]
      logger.debug "Candidates: #{candidates.inspect}"

      package_path = candidates.select { |_| _ }.find { |_| File.exists?(_) }

      unless package_path
        fatal! "Package (#{package_atom}) couldn't find at #{candidates.join(', ')}"
      end

      package_path
    end
  end
end

require 'mamiya/cli/client'
