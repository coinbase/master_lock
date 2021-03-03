require 'master_lock/redis_scripts'

module MasterLock
  # RedisLock implements a mutex in Redis according to the strategy documented
  # at http://redis.io/commands/SET#patterns. The lock has a string identifier
  # and when acquired will be registered to an owner, also identified by a
  # string. Locks have an expiration time, after which they will be released
  # automatically so that unexpected failures do not result in locks getting
  # stuck.
  class RedisLock
    DEFAULT_SLEEP_INTERVAL = 0.1

    # @return [Config] backend's config which includes redis connection used to manage lock
    attr_reader :config

    # @return [String] the unique identifier for the locked resource
    attr_reader :key

    # @return [String] the identity of the owner acquiring the lock
    attr_reader :owner

    # @return [Fixnum] the lifetime of the lock in seconds
    attr_reader :ttl

    def initialize(
      config:,
      key:,
      owner:,
      ttl:,
      sleep_interval: DEFAULT_SLEEP_INTERVAL
    )
      @config = config
      @key = key
      @owner = owner
      @ttl = ttl
      @sleep_interval = sleep_interval
    end

    # Attempt to acquire the lock. If the lock is already held, this will
    # attempt multiple times to acquire the lock until the timeout period is up.
    #
    # @param [Fixnum] how long to wait to acquire the lock before failing
    # @return [Boolean] whether the lock was acquired successfully
    def acquire(timeout:)
      timeout_time = Time.now + timeout
      loop do
        locked = redis.set(redis_key, owner, nx: true, px: ttl_ms)
        return true if locked
        return false if Time.now >= timeout_time
        sleep(@sleep_interval)
      end
    end

    # Extend the expiration time of the lock if still held by this owner. If the
    # lock is no longer held by the owner, this method will fail and return
    # false. The lock lifetime is extended by the configured ttl.
    #
    # @return [Boolean] whether the lock was extended successfully
    def extend
      result = eval_script(
        RedisScripts::EXTEND_SCRIPT,
        RedisScripts::EXTEND_SCRIPT_HASH,
        keys: [redis_key],
        argv: [owner, ttl_ms]
      )
      result != 0
    end

    # Release the lock if still held by this owner. If the lock is no longer
    # held by the owner, this method will fail and return false.
    #
    # @return [Boolean] whether the lock was released successfully
    def release
      result = eval_script(
        RedisScripts::RELEASE_SCRIPT,
        RedisScripts::RELEASE_SCRIPT_HASH,
        keys: [redis_key],
        argv: [owner]
      )
      result != 0
    end

    private

    def ttl_ms
      (ttl * 1000).to_i
    end

    def eval_script(script, script_hash, keys:, argv:)
      begin
        redis.evalsha(script_hash, keys: keys, argv: argv)
      rescue Redis::CommandError
        redis.eval(script, keys: keys, argv: argv)
      end
    end

    def redis_key
      # Key hash tags are a way to ensure multiple keys are allocated in the same hash slot.
      # This allows our redis operations to work with clusters
      if config.cluster
        "{#{MasterLock.config.key_prefix}}:#{key}"
      else
        "#{MasterLock.config.key_prefix}:#{key}"
      end
    end

    def redis
      config.redis
    end
  end
end
