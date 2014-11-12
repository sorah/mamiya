# Quick Start

## What's mamiya?

Mamiya allows you to deploy using without ssh -- using tarballs, some storages (S3, etc), and [Serf](http://www.serfdom.io/).
Build application package on CI or somewhere, then distribute earlier (before you say "Deploy!"). You can switch to an new application quickly, when you're saying "deploy."

Also, this free you from SSH and RSync problems.

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

##
