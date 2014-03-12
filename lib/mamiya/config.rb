require 'mamiya/dsl'

module Mamiya
  class Config < DSL
    add_hook :before_build
    add_hook :prepare_build
    add_hook :build
    add_hook :after_build

    add_hook :before_distribute
    add_hook :after_distribute

    add_hook :before_prepare
    add_hook :prepare
    add_hook :after_prepare

    add_hook :before_finalize
    add_hook :finalize
    add_hook :after_finalize

    add_hook :before_rollback
    add_hook :rollback
    add_hook :after_rollback

    add_hook :package_name, chain: true

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

    set_default :package_to, nil
    set_default :deploy_to, nil
    set_default :prepare_to, nil

    def run(*args)
      system *args
    end

    def servers
    end

    def servers_use
    end

    def storage(name, options={})
    end
  end
end
