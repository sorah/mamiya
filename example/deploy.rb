require 'digest/sha1'
require 'fileutils'
require 'pathname'

set :application, 'myapp'
#set :repository, '...'

#set :package_under, 'dir'
set :exclude_from_package, ['tmp', 'log', 'spec', '.sass-cache']
set :dereference_symlinks, true

# http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?revision=45360&view=revision
set :build_from, "#{File.dirname(__FILE__)}/source"
set :build_to, "#{File.dirname(__FILE__)}/builds"

# to test it
Dir.mkdir build_to unless File.exist?(build_to)

#set :bundle_without, [:development, :test]
#set :bundle_dir, "#{deploy_to}/shared/bundle"

#use :git, exclude_git_clean_targets: true

#prepare_build("bundle install") do
#  run "bundle", "install"
#end

build("test") do
  File.write('built_at', "#{Time.now}\n")
end

#build("include assets and .bundle") do
#  exclude_from_package.reject! { |_| _ == 'public/assets/' }
#  exclude_from_package.reject! { |_| _ == '.bundle/' }
#end
#
#build("assets compile") do
#  run "bundle", "exec", "rake", "assets:precompile"
#end

prepare 'test' do
  # run 'bundle', 'install'
  logger.info "- prep/deploy_to: #{deploy_to}"
  logger.info "- prep/release_path: #{release_path}"
end

release 'test' do
  # run 'bundle', 'install'
  logger.info "- prep/deploy_to: #{deploy_to}"
  logger.info "- prep/release_path: #{release_path}"
end


