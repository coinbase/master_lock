# MasterLock

[![Build Status](https://travis-ci.org/coinbase/master_lock.svg?branch=master)](https://travis-ci.org/coinbase/master_lock)
[![Coverage Status](https://coveralls.io/repos/github/coinbase/master_lock/badge.svg?branch=master)](https://coveralls.io/github/coinbase/master_lock?branch=master)
[![Gem Version](https://badge.fury.io/rb/master_lock.svg)](https://badge.fury.io/rb/master_lock)

MasterLock is a Ruby library for interprocess locking using Redis. Critical sections of code can be wrapped in a MasterLock block that ensures only one thread will run the code at a time. The locks are resilient to process failures by expiring after the thread obtaining them dies.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'master_lock'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install master_lock

## Usage

```ruby
def perform_safe_operation
  MasterLock.synchronize("perform_safe_operation") do
    # Code executes within locked context
  end
end

# Call MasterLock.start when your application boots up.
# This starts a background thread to prevent locks from expiring.
MasterLock.start
```

See [documentation](http://www.rubydoc.info/gems/master_lock) for advanced usage.

## Development

After checking out the repo, run `bundle install` to install the gem dependencies. 

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
### Testing
If you do not have Redis set up, run `brew install redis`. This gives you access to `redis-server`.

To set up the redis instance, run `redis-server` in the project level directory. The default config should be located at `/usr/local/etc/redis.conf`.

To set up the redis cluster, copy your redis-server executable to `cluster-test/redis-server`. Open up 6 terminal tabs, and in every tab, start every instance:
```
cd cluster-test/7000
../redis-server ./redis.conf
```
Assuming you have at least Redis 5, create your cluster by running the following:
```
redis-cli --cluster create 127.0.0.1:7000 127.0.0.1:7001 \
127.0.0.1:7002 127.0.0.1:7003 127.0.0.1:7004 127.0.0.1:7005 \
--cluster-replicas 1
```

Then, run `rake spec` to run the tests. 

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/coinbase/master_lock.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
