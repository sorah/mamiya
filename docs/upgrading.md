# Upgrade Notes

## 0.0.1.alpha21

### Configuration now written in Ruby

You should rewrite your configuration yaml in Ruby. See examples/config.rb for example.

## 0.0.1.alpha20

_tl;dr_ Don't mix alpha19 and alpha20.

### Internal component for distribution has been replaced completely

alpha20 introduces new class `TaskQueue` and removes `Fetcher`. This changes way to distribute packages -- including internal serf events, job tracking that Distribution API does, etc.
So basically there's no compatibility for distribution, between alpha19 and alpha20 and later. Distribute task from alpha20 doesn't effect to alpha19, and vice versa.

Good new: There's no change in Distribution API.

### Agent status has changed

- Due to removal of `Fetcher`, alpha20 removes `.fetcher` object from agent status.
- Added `.queues`, represents task queues that managed by `TaskQueue` class.


