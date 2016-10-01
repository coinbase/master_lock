require 'master_lock/redis_scripts'

module MasterLock
  class RedisLock
    DEFAULT_SLEEP_INTERVAL = 0.1

    # @return [Redis] the Redis connection used to manage lock
    attr_reader :redis

    # @return [String] the unique identifier for the lock
    attr_reader :key

    # @return [String] the identity of the owner acquiring the lock
    attr_reader :owner

    # @return [Fixnum] the lifetime of the lock in seconds
    attr_reader :ttl

    def initialize(
      redis:,
      key:,
      owner:,
      ttl:,
      sleep_interval: DEFAULT_SLEEP_INTERVAL
    )
      @redis = redis
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
        locked = redis.set(key, owner, nx: true, px: ttl_ms)
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
        keys: [key],
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
        keys: [key],
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
  end
end
