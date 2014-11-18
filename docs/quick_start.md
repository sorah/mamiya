# Quick Start

## What's mamiya?

Mamiya allows you to deploy using without ssh -- using tarballs, some storages (S3, etc), and [Serf](http://www.serfdom.io/).
Build application package on CI or somewhere, then distribute earlier (before you say "Deploy!"). You can switch to an new application quickly, when you're saying "deploy."

Also, this free you from SSH and RSync problems.

## Concepts

- __Package__ is a tarball contains your application.
- __Storage__ is a place to store package.
- __Script__ is a Ruby script that defines how to deploy (prepare, restart, etc) your application.

- __CI (or, somewhere)__ builds packages and push them on _Storage_
- __Master__ controls the cluster of _Agents_
- __Agent__ receives deployment and do it.

## Prepare master and agent

Run `sudo gem install mamiya` to install mamiya on your systems.

(TODO: write init.d/systemd/upstart script for easier boot up)

### Master

On a server for master node; it'll controll the cluster:

#### Configure

typical configuration for the master here:

``` ruby
# /etc/mamiya/config.rb

set :storage, {
  type: :s3,
  bucket: 'YOUR-S3-BUCKET-NAME',
  region: 'ap-northeast-1', # set it to your region
  access_key_id: '...',
  secret_access_key: '...',
}

set :serf, {
  agent: {
    bind: "0.0.0.0:7760",
    rpc_addr: "127.0.0.1:7762",
  }
}

set :web, {
  port: 7761,
}
```

#### Run it

```
mamiya master -c /etc/mamiya/config.rb
```

### Agent

On a server for agent node; where the package will be deployed:

#### Configure

typical configuration for the agents here:

``` ruby
# /etc/mamiya/config.rb

set :storage, {
  type: :s3,
  bucket: 'YOUR-S3-BUCKET-NAME',
  region: 'ap-northeast-1', # set it to your region
  access_key_id: '...',
  secret_access_key: '...',
}

set :serf, {
  agent: {
    bind: "0.0.0.0:7760",
    rpc_addr: "127.0.0.1:7762",
    join: 'YOUR-MASTER-HOST:7760', # set it to your master host
  }
}

set :web, {
  port: 7761,
}

# Where should the application go. :myapp is a Symbol to identify application.
applications[:myapp] = {deploy_to: '/home/app/myapp'}

# Where should Mamiya store packages, pre-releases temporarily.
set :packages_dir, '/tmp/mamiya/packages'
set :prereleases_dir, '/tmp/mamiya/prereleases'

# And how many you want to keep them?
set :keep_packages, 3
set :keep_prereleases, 3
```

#### Run it

```
mamiya master -c /etc/mamiya/config.rb
```

### Confirm both working

Use `mamiya client` command family to communicate with master process. By default `http://localhost:7761/` is used. You can change by `-m`, `--master` option or `$MAMIYA_MASTER_URL` environment variable.

```
master $ mamiya client list-agents
AGENT_NAME	alive
```

## Prepare deploy script

_Script_ should have required operations and configurations for an application being deployed.

```
set :application, 'myapp'

# Using for package build
set :exclude_from_package, ['tmp', 'log', 'spec', '.sass-cache']
set :dereference_symlinks, true
set :build_from, "/tmp/build_from"
set :build_to, "./builds"
# set :package_under, 'dir'

# You may use helpers here
#  set :repository, '...'
#  use :git, exclude_git_clean_targets: true

# Procedure for build
build 'write built at' do
  # build something...
  File.write('built_at', "#{Time.now}\n")
end

# Step `prepare` on agents,
prepare 'write prepared_at' do
  File.write release_path.join('prepared_at'), Time.now
end

# You can declare multiples. Run by order defined.
prepare 'bundle stuff' do
  run 'bundle', 'install'
end

# Step `release` run when Release is required. Usually for restarting app process, etc.
# Also these step declaration accepts labels for `only` and `except` key to limit agents to run on.
# (Labels can be set by agent's configuration)
release 'reload unicorn', only [:app] do
  run 'pkill', '-HUP', '-f', 'unicorn'
end
```
