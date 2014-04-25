module Mamiya
  class Agent
    module Actions
      def distribute(application, package)
        trigger('fetch',
          application: application,
          package: package,
        )
      end
    end
  end
end
