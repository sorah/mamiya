module Mamiya
  class Agent
    module Actions
      def order_task(task, coalesce: false, **payload)
        trigger('task',
          coalesce: coalesce,
          task: task,
          **payload,
        )
      end

      def distribute(application, package)
        order_task('fetch', application: application, package: package)
      end
    end
  end
end
