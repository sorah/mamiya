require 'mamiya'
require 'thor'

module Mamiya
  class CLI < Thor
    def status
    end

    def packages
    end

    # ---

    desc "Run build->push->distribute->prepare->finalize"
    def deploy
    end

    desc "Switch back to previous release then finalize"
    def rollback
    end

    desc "Build package."
    def build
    end

    desc "Upload built packages to storage."
    def push

    desc "Order clients to download specified package."
    def distribute
    end

    desc "Prepare package on clients."
    def prepare
    end

    desc "Finalize (start) prepared package on clients."
    def finalize
    end


    # ---

    def master
    end

    def client
    end

    def worker
    end

    def event_handler
    end
  end
end
