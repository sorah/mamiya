require 'pathname'

if ENV['MAMIYA_S3_BUCKET'] || ENV['S3_BUCKET']
  set :storage, {
    type: :s3,
    bucket: ENV["MAMIYA_S3_BUCKET"] || ENV["S3_BUCKET"],
    region: ENV["AWS_REGION"] || 'ap-northeast-1',
  }
else
  set :storage, {
    type: :filesystem,
    path: File.join(File.dirname(__FILE__), 'packages'),
  }
end

set :serf, {
  agent: {
    bind: "0.0.0.0:#{ENV['PORT']}",
    rpc_addr: "127.0.0.1:#{ENV['PORT']}",
    join: "127.0.0.1:7760",
    node: "#{ENV['HOSTNAME']}_#{ENV['PORT']}",
  }
}
p serf

agent_name = ENV['PORT'].to_s

targets = Pathname.new(File.dirname(__FILE__)).join('targets')
target = targets.join(agent_name).tap(&:mkpath)

set :packages_dir, target.join('packages')
set :prereleases_dir, target.join('prereleases')

# To test
Dir.mkdir packages_dir unless File.exist?(packages_dir)
Dir.mkdir prereleases_dir unless File.exist?(prereleases_dir)

set :keep_packages, 3
set :keep_prereleases, 3
set :fetch_sleep, 2
