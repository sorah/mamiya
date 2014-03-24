require 'mamiya'
require 'mamiya/config'
require 'mamiya/script'

require 'mamiya/steps/build'
require 'mamiya/steps/push'

require 'thor'

module Mamiya
  class CLI < Thor
    class_option :config, aliases: '-C', type: :string
    class_option :script, aliases: '-S', type: :string
    class_option :application, aliases: %w(-a --app), type: :string
    # TODO: class_option :set, aliases: '-s', type: :array

    desc "status", ""
    def status
      # TODO:
    end

    desc "list-packages", "List packages in storage"
    method_option :name_only, aliases: '-n'
    def list_packages
      unless options[:name_only]
        puts "Available packages in #{application}:"
        puts ""
      end

      puts storage.packages
    end

    desc "list-applications", "List applications in storage"
    def list_applications
      puts _applications.keys
    end

    # ---

    desc "deploy PACKAGE", "Run build->push->distribute->prepare->finalize"
    def deploy
    end

    desc "rollback", "Switch back to previous release then finalize"
    def rollback
    end

    desc "build", "Build package."
    method_option :build_from, aliases: %w(--source -f), type: :string
    method_option :build_to, aliases: %w(--destination -t), type: :string
    def build
      # TODO: overriding name
      %i(build_from build_to).each { |k| script.set(k, File.expand_path(options[k])) if options[k] }

      Mamiya::Steps::Build.new(script: script).run!
    end

    desc "push PACKAGE", "Upload built packages to storage."
    def push(package_atom)
      candidates = [
        package_atom,
        options[:build_from] && File.join(options[:build_from], package_atom),
        options[:build_from] && File.join(options[:build_from], "#{package_atom}.tar.gz"),
        script(:no_error) && script.build_from && File.join(script.build_from, package_atom),
        script(:no_error) && script.build_from && File.join(script.build_from, "#{package_atom}.tar.gz"),
      ]
      package_path = candidates.select { |_| _ }.find { |_| File.exists?(_) }

      unless package_path
        abort "Package (#{package_atom}) couldn't find at #{candidates.join(', ')}"
      end

      if options[:application]
        warn "WARNING: Overriding package's application name with given one: #{options[:application]}"
        sleep 2
      end

      Mamiya::Steps::Push.new(
        config: config,
        package: package_path,
        application: options[:application],
      ).run!
    end

    desc "distribute PACKAGE", "Order clients to download specified package."
    def distribute
    end

    desc "prepare", "Prepare package on clients."
    def prepare
    end

    desc "finalize", "Finalize (start) prepared package on clients."
    def finalize
    end


    # ---

    # def master
    # end

    # def client
    # end

    # def worker
    # end

    # def event_handler
    # end

    private

    def config(dont_raise_error = false)
      return @config if @config
      path = [options[:config], './mamiya.yml', './config.yml'].compact.find { |_| File.exists?(_) }

      if path
        @config = Mamiya::Config.load(File.expand_path(path))
      else
        return nil if dont_raise_error
        abort "Configuration File not found (try --config(-C) option or place it at ./mamiya.yml or ./config.yml)"
      end
    end

    def script(dont_raise_error = false)
      return @script if @script
      path = [options[:script], './mamiya.rb', './deploy.rb'].compact.find { |_| File.exists?(_) }

      if path
        @script = Mamiya::Script.new.load!(File.expand_path(path)).tap do |s|
          s.set :application, options[:application] if options[:application]
        end
      else
        return nil if dont_raise_error
        abort "Deploy Script File not found (try --script(-S) option or place it at ./mamiya.rb or ./deploy.rb)"
      end
    end

    def storage
      config.storage_class.new(
        config[:storage].merge(
          application: options[:application] || config[:application] || script.application
        )
      )
    end

    def _applications
      config.storage_class.find(config[:storage])
    end
  end
end
