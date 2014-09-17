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

set :packages_dir, "#{File.dirname(__FILE__)}/packages"
set :prereleases_dir, "#{File.dirname(__FILE__)}/target/prereleases"

applications[:myapp] = {deploy_to: File.join(File.dirname(__FILE__), 'targets', 'default')}

# To test
Dir.mkdir packages_dir unless File.exist?(packages_dir)
prereleases_dir.mkpath unless File.exist?(prereleases_dir)
deploy_to_for(:myapp).mkpath unless deploy_to_for(:myapp).exist?

set :keep_packages, 3
set :keep_prereleases, 3
set :fetch_sleep, 2

before_deploy do
  p :before_deploy
end

after_deploy do |e|
  p [:after_deploy, e]
end

before_rollback do
  p :before_rollback
end

after_rollback do |e|
  p [:after_rollback, e]
end

before_deploy_or_rollback do
  p :before_deploy_or_rollback
end

after_deploy_or_rollback do |e|
  p [:after_deploy_or_rollback, e]
end
