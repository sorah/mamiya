require 'mamiya/dsl'
require 'mamiya/storages'

require 'shellwords'

module Mamiya
  class Configuration < DSL
    # common
    set_default :serf, {}
    set_default :storage, {}

    set_default :show_backtrace_in_fatal, true
    set_default :debug_all_events, false

    set_default :application, nil

    # agent
    set_default :packages_dir, nil
    set_default :prereleases_dir, nil
    set_default :fetch_sleep, 12
    set_default :keep_packages, 3
    set_default :keep_prereleases, 3
    set_default :keep_releases, 3
    set_default :applications, {}

    # master
    set_default :master, {monitor: {refresh_interval: nil}} # TODO: don't nest
    set_default :web, {port: 7761, bind: '0.0.0.0', environment: :development} # TODO: IPv6
    set_default :synced_release, false

    add_hook :labels, chain: true

    add_hook :before_deploy_or_rollback
    add_hook :after_deploy_or_rollback

    add_hook :before_deploy
    add_hook :after_deploy

    add_hook :before_rollback
    add_hook :after_rollback

    def storage_class
      Storages.find(self[:storage][:type])
    end

    def packages_dir
      self[:packages_dir] && Pathname.new(self[:packages_dir])
    end

    def prereleases_dir
      self[:prereleases_dir] && Pathname.new(self[:prereleases_dir])
    end

    # XXX: `config.app(app_name).deploy_to` form is better?
    def deploy_to_for(app)
      # XXX: to_sym
      application = applications[app.to_sym] || applications[app.to_s]
      application && application[:deploy_to] && Pathname.new(application[:deploy_to])
    end
  end
end

