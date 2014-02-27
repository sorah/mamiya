set :deploy_to, "/home/app/app"
set :repository, "some@where:repo.git"
set :branch, "master"
set :build_on, "/tmp/app-build"
set :package_under, 'suffix'

servers ec2.instances
servers ec2.instances

use_servers :app, stage
use_servers :web, stage


set :discover_servers, false
set :on_client_failure, :warn

use :git, skip_naming: true
use :rails

# chainable
package_meta_handler do |meta|
  meta.merge(...)
end

build(:prepend) do
  # ...
end

prepare(only: :app) do
  invoke :'bundle:install'
end

finalize(except: :web) do
  run "unicorn", "graceful"
end

# finalize(:overwrite) do
#   invoke :'deploy:switch_current'
#   run "unicorn", "graceful"
# end

# ---- git.rb

set_default :branch, "master"

task :'git:clone' do
  run 'git', 'clone', ...
end

task :'git:checkout' do
  next if skip_checkout
  # ...
end

unless options[:no_build_prepare]
  prepare_build(:overwrite) do
    invoke :'git:clone'
    invoke :'git:checkout'
  end
end

# ---- rails.rb

task :'rails:assets_precompile' do
  # ...
end

build do
  invoke :'rails:assets_precompile'
end
