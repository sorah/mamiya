# Mamiya - Faster deploy tool using tarballs and serf

[![Build Status](https://travis-ci.org/sorah/mamiya.png?branch=master)](https://travis-ci.org/sorah/mamiya)

Mamiya allows you to deploy using without ssh -- using tarballs, some storages (S3, etc), and [Serf](http://www.serfdom.io/).

## Installation

(Detailed documentation coming soon)

1. Install gem (`gem install mamiya`, or bundling by `gem 'mamiya'`)
2. Prepare master node for `mamiya master` process
  - master has HTTP API to allow control the cluster via HTTP
  - master watches agents in the cluster
3. Then install `mamiya agent` in your deployment target hosts
4. Write deploy script for your own
  - how to build package, how to prepare release, how to release, etc.
5. Build then push package
  - `mamiya build`
  - `mamiya push path/to/package.tar.gz`
6. Time to deploy: `mamiya client deploy -a app package`

### Example configuration

[example](./example) directory contains configuration files that work out-of-the-box.
Try Mamiya in your local machine: `foreman start`

## Problems in existing deploy tool

Existing major deploy tools (capistrano, mina, ...) use SSH to operate servers.
But connecting to lot of servers via SSH makes deployment slow.

This solves such problem by using [Serf](http://www.serfdom.io/) and tarball on one storage (Amazon S3).

Also, I'm planning to allow to distribute files before the deploy command. I guess this can skip or shorten
file transferring phase in deploy.

## In the production

- [Cookpad](https://info.cookpad.com/en) is using Mamiya in production of [cookpad.com](http://cookpad.com).

## Misc.

- [Scalable Deployments - How we deploy Rails app to 150+ hosts in a minute // Speaker Deck](https://speakerdeck.com/sorah/scalable-deployments-how-we-deploy-rails-app-to-150-plus-hosts-in-a-minute)

## Upgrade Notes

See [docs/upgrading.md](./docs/upgrading.md).

## Contributing

1. Fork it ( http://github.com/sorah/mamiya/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
