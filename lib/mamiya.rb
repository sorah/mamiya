require "mamiya/version"
require 'thread'

module Mamiya

  @chdir_mutex = Thread::Mutex.new
  def self.chdir(dir, &block)
    @chdir_mutex.synchronize do
      Dir.chdir(dir, &block)
    end
  end
end
