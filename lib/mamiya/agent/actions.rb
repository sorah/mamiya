module Mamiya
  class Agent
    module Actions
      # XXX: dupe?
      def distribute(application, package)
        trigger('fetch',
          application: application,
          package: package,
          coalesce: false
        )
      end
    end
  end
end
