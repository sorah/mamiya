require "mamiya/version"
require 'thread'

module Mamiya

  @chdir_monitor = Monitor.new
  def self.chdir(dir, &block)
    @chdir_monitor.synchronize do
      Dir.chdir(dir, &block)
    end
  end
end
