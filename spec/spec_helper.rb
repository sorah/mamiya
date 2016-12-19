require 'simplecov'
require 'rack/test'
SimpleCov.start do
  add_filter "/spec/"
end

require 'mamiya/storages/mock'
require 'mamiya/logger'

module Rack
  module Test
    class Session
      def envs
        @envs ||= {}
      end

      alias_method :default_env_orig, :default_env
      def default_env
        default_env_orig.merge(envs)
      end
    end
  end
end

unless ENV["ENABLE_LOG"]
  Mamiya::Logger.defaults[:outputs] = []
end

RSpec.configure do |config|
  config.raise_errors_for_deprecations!

  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.after(:each) do
    Mamiya::Storages::Mock.clear
  end

  config.before(:suite) do
    %w(AWS_ACCESS_KEY AWS_ACCESS_KEY_ID AMAZON_ACCESS_KEY_ID
       AWS_SECRET_KEY AWS_SECRET_ACCESS_KEY AMAZON_SECRET_ACCESS_KEY
       AWS_SESSION_TOKEN AMAZON_SESSION_TOKEN).each do |key|
      ENV.delete key
    end
  end
end
