set :storage, {
  type: :s3,
  bucket: ENV["MAMIYA_S3_BUCKET"] || ENV["S3_BUCKET"],
  region: ENV["AWS_REGION"] || 'ap-northeast-1',
}

require 'pathname'

targets = Pathname.new(File.dirname(__FILE__)).join('targets')
targets.mkpath

agent_name = self.serf[:agent][:node] or raise 'no node name'
target = targets.join(agent_name).tap(&:mkpath)

set :packages_dir, target.join('packages')
set :prereleases_dir, target.join('prereleases')

# To test
Dir.mkdir packages_dir unless File.exist?(packages_dir)
Dir.mkdir prereleases_dir unless File.exist?(prereleases_dir)

set :keep_packages, 3
set :keep_prereleases, 3
set :fetch_sleep, 2
