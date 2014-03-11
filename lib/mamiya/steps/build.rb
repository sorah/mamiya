require 'mamiya/package'

module Mamiya
  module Steps
    class Build
      def initialize(config)
        @config = config
      end

      attr_reader :config

      def run!
        config.before_build[]

        unless config.skip_prepare_build
          config.prepare_build[config.build_from.exist?]
        end

        Dir.chdir(config.build_from) do
          config.build[]
        end

        package_path = File.join(config.build_to, Time.now.strftime("%Y-%m-%d_%H.%M.%S-#{config.application}.tar.bz2"))
        package = Mamiya::Package.new(package_path)

        package.build!(config.build_from,
           exclude_from_package: config.exclude_from_package || [],
           dereference_symlinks: config.dereference_symlinks || false,
           package_under: config.package_under || nil)

        config.after_build[]
      end
    end
  end
end
