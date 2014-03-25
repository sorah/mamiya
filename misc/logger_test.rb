require 'bundler/setup'
$:.unshift File.join(__dir__, '..' ,'lib')
require 'mamiya/logger'

[true,false].each {|color|
  l = Mamiya::Logger.new(level: Logger::DEBUG, color: color)
  [nil, "app"].each {|n|
    (0..5).each {|s|
      l.log s, "hi", n
    }
  }
}
