require 'mamiya/steps/abstract'
require 'mamiya/package'

module Mamiya
  module Steps
    class Build < Abstract
      def run!
        script.before_build[]

        unless script.skip_prepare_build
          script.prepare_build[script.build_from.exist?]
        end

        Dir.chdir(script.build_from) do
          script.build[]
        end

        package_path = File.join(script.build_to, Time.now.strftime("%Y-%m-%d_%H.%M.%S-#{script.application}.tar.gz"))
        package = Mamiya::Package.new(package_path)

        package.build!(script.build_from,
           exclude_from_package: script.exclude_from_package || [],
           dereference_symlinks: script.dereference_symlinks || false,
           package_under: script.package_under || nil)

        script.after_build[]
      end
    end
  end
end
