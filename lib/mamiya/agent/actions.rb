module Mamiya
  class Agent
    module Actions
      def order_task(task, coalesce: false, labels: nil, **payload)
        payload[:_labels] = labels if labels
        trigger('task',
          coalesce: coalesce,
          task: task,
          **payload,
        )
      end

      def distribute(application, package, labels: nil)
        order_task('fetch', app: application, pkg: package, labels: labels)
      end

      def prepare(application, package, labels: nil)
        order_task('prepare', app: application, pkg: package, labels: labels)
      end

      def switch(application, package, labels: nil)
        order_task('switch', app: application, pkg: package, labels: labels)
      end
    end
  end
end
