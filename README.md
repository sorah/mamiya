# Mamiya - Faster deploy tool using tarballs and serf

[![Build Status](https://travis-ci.org/sorah/mamiya.png?branch=master)](https://travis-ci.org/sorah/mamiya)

Mamiya allows you to deploy using without ssh -- using tarballs, some storages (S3, etc), and [Serf](http://www.serfdom.io/).

## Installation

    $ gem install mamiya

or bundle it:

``` ruby
gem 'mamiya'
```

## Usage

(Detailed documentation coming soon)

1. Prepare master node for `mamiya master` process
  - master has HTTP API to allow control the cluster via HTTP
  - master watches agents in the cluster
2. Then install `mamiya agent` in your deployment target hosts
3. Write deploy script for your own
  - how to build package, how to prepare release, how to release, etc.
4. Build then push package
5. Time to deploy

[example](./example) directory contains configuration files that work out-of-the-box. Try Mamiya in your local machine: `foreman start`

## Problems in existing deploy tool

Existing major deploy tools (capistrano, mina, ...) use SSH to operate servers.
But connecting to lot of servers via SSH makes deployment slow.

This solves such problem by using [Serf](http://www.serfdom.io/) and tarball on one storage (Amazon S3).

Also, I'm planning to allow to distribute files before the deploy command. I guess this can skip or shorten
file transferring phase in deploy.


## Upgrade Notes

### 0.0.1.alpha21

#### Configuration now written in Ruby

You should rewrite your configuration yaml in Ruby. See examples/config.rb for example.

### 0.0.1.alpha20

_tl;dr_ Don't mix alpha19 and alpha20.

#### Internal component for distribution has been replaced completely

alpha20 introduces new class `TaskQueue` and removes `Fetcher`. This changes way to distribute packages -- including internal serf events, job tracking that Distribution API does, etc.
So basically there's no compatibility for distribution, between alpha19 and alpha20 and later. Distribute task from alpha20 doesn't effect to alpha19, and vice versa.

Good new: There's no change in Distribution API.

#### Agent status has changed

- Due to removal of `Fetcher`, alpha20 removes `.fetcher` object from agent status.
- Added `.queues`, represents task queues that managed by `TaskQueue` class.

## Contributing

1. Fork it ( http://github.com/sorah/mamiya/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
