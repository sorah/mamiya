set :storage, {
  type: :s3,
  bucket: ENV["MAMIYA_S3_BUCKET"] || ENV["S3_BUCKET"] || raise("specify your S3 bucket via $MAMIYA_S3_BUCKET or $S3_BUCKET"),
  region: ENV["AWS_REGION"] || 'ap-northeast-1',
}

set :packages_dir, "#{File.dirname(__FILE__)}/dst"
set :keep_packages, 3
set :fetch_sleep, 2
