require 'digest/sha1'
require 'fileutils'
require 'pathname'

set :application, 'myapp'
#set :repository, '...'

#set :package_under, 'dir'
set :exclude_from_package, ['tmp', 'log', 'spec', '.sass-cache']
set :dereference_symlinks, true

# http://svn.ruby-lang.org/cgi-bin/viewvc.cgi?revision=45360&view=revision
set :build_to, "#{File.dirname(__FILE__)}/pkg"
set :deploy_to, "..."

set :bundle_without, [:development, :test]
set :bundle_dir, "#{deploy_to}/shared/bundle"

#use :git, exclude_git_clean_targets: true

prepare_build("bundle install") do
  run "bundle", "install"
end

build("include assets and .bundle") do
  exclude_from_package.reject! { |_| _ == 'public/assets/' }
  exclude_from_package.reject! { |_| _ == '.bundle/' }
end

build("assets compile") do
  run "bundle", "exec", "rake", "assets:precompile"
end


