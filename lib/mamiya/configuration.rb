require 'mamiya/dsl'
require 'mamiya/storages'

require 'shellwords'

module Mamiya
  class Configuration < DSL
    # common
    set_default :serf, {}
    set_default :storage, {}
    set_default :show_backtrace_in_fatal, true

    set_default :application, nil

    # agent
    set_default :packages_dir, nil
    set_default :fetch_sleep, 12
    set_default :keep_packages, 3

    # master
    set_default :master, {monitor: {refresh_interval: nil}} # TODO: don't nest
    set_default :web, {port: 7761, bind: '0.0.0.0', environment: :development} # TODO: IPv6

    def storage_class
      Storages.find(self[:storage][:type])
    end
  end
end

