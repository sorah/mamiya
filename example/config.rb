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
