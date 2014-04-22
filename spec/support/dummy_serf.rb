class DummySerf
  def initialize()
    @hooks = {}

    @tags = {}
    class << @tags
      alias_method :update, :merge!
    end
  end

  attr_reader :tags

  def name
    'my-name'
  end

  def start!
  end

  def auto_stop
  end

  def event(name, payload)
  end

  %w(member_join member_leave member_failed
     member_update member_reap
     user_event query stop event).each do |event|

    define_method(:"on_#{event}") do |&block|
      hooks(event) << block
    end
  end

  def hooks(name)
    @hooks[name] ||= []
  end

  def trigger(name, *args)
    hooks(name).each do |hook|
      hook.call(*args)
    end
    nil
  end
end
