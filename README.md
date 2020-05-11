# Mamiya - Faster deploy tool using tarballs and serf

[![Build Status](https://travis-ci.org/sorah/mamiya.png?branch=master)](https://travis-ci.org/sorah/mamiya)


## What's mamiya?

Mamiya allows you to deploy without ssh -- using tarballs, some storages (S3, etc), and [Serf](http://www.serfdom.io/).
Build application package on CI or somewhere, then distribute earlier (before you say "Deploy!"). You can switch to a new application quickly, when you're saying "deploy."

Mamiya uses similar directory structure with Capistrano 'deploy_to' -- you can try this easy.

## Quick Start

See [./docs/quick_start.md](./docs/quick_start.md).

### Example configuration

[example](./example) directory contains configuration files that work out-of-the-box.
Try Mamiya in your local machine: `foreman start`

## Problems in existing deploy tool

Existing major deploy tools (capistrano, mina, ...) use SSH to operate servers.
But connecting to lot of servers via SSH makes deployment slow.

Mamiya solves such problem by using [Serf](http://www.serfdom.io/) and tarball on one storage (Amazon S3).

Also, I'm planning to allow to distribute files before the deploy command. I guess this can skip or shorten
file transferring phase in deploy.

## In the production

- [Cookpad](https://info.cookpad.com) was using Mamiya in production of [cookpad.com](http://cookpad.com). (until it migrates to full-containerized environment)

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
