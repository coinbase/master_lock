require 'master_lock/version'

require 'socket'

# MasterLock is a system for interprocess locking. Resources can be locked by a
# string identifier such that only one thread may have the lock at a time. Lock
# state and owners are stored on a Redis server shared by all processes. Locks
# are held until either the block of synchronized code completes or the thread
# that obtained the lock is killed. To prevent the locks from being held
# indefinitely in the event that the process dies without releasing them, the
# locks have an expiration time in Redis. While the thread owning the lock is
# alive, a separate thread will extend the lifetime of the locks so that they
# do not expire even when the code in the critical section takes a long time to
# execute.
module MasterLock
  class UnconfiguredError < StandardError; end
  class NotStartedError < StandardError; end
  class LockNotAcquiredError < StandardError; end

  DEFAULT_TTL = 60
  DEFAULT_ACQUIRE_TIMEOUT = 5
  DEFAULT_EXTEND_INTERVAL = 15

  Config = Struct.new(
    :redis,
    :ttl,
    :acquire_timeout,
    :extend_interval,
    :hostname,
    :process_id
  )

  class << self
    # Obtain a mutex around a critical section of code. The lock is respected across processes and
    # instances in the deployment of the project.
    #
    # @option options [ActiveSupport::Duration] :life (60.seconds) the length of time before the
    #   lock expires
    # @option options [ActiveSupport::Duration] :acquire (10.seconds) the length of time to wait
    #   to acquire the lock before timing out
    # @option options [ActiveSupport::Duration] :extend_interval (10.seconds) the amount of time
    #   that may pass before extending the lock
    # @option options [Boolean] :if if this option is falsey, the block will be executed without
    #   obtaining the lock
    # @option options [Boolean] :unless if this option is truthy, the block will be executed
    #   without obtaining the lock
    def synchronize(key, options = {})
      check_configured
      raise NotStartedError unless @registry

      ttl = options[:ttl] || config.ttl
      acquire_timeout = options[:acquire_timeout] || config.acquire_timeout
      extend_interval = options[:extend_interval] || config.extend_interval

      raise ArgumentError, "ttl must be greater than 0" if ttl <= 0

      if (options.include?(:if) && !options[:if]) ||
          (options.include?(:unless) && options[:unless])
        return yield
      end

      lock = RedisLock.new(
        redis: config.redis,
        key: key,
        ttl: ttl,
        owner: generate_owner
      )
      if !lock.acquire(timeout: acquire_timeout)
        raise LockNotAcquiredError, key
      end

      registration =
        @registry.register(lock, extend_interval)
      begin
        yield
      ensure
        @registry.unregister(registration)
        redis_lock.release # TODO: Check result of this
      end
    end

    def start
      @registry = Registry.new
      Thread.new do
        loop do
          @registry.extend_locks
          sleep(config.sleep_time)
        end
      end
    end

    def config
      if @config.nil?
        @config = Config.new
        @config.ttl = DEFAULT_TTL
        @config.acquire_timeout = DEFAULT_ACQUIRE_TIMEOUT
        @config.extend_interval = DEFAULT_EXTEND_INTERVAL
        @config.hostname = Socket.gethostname
        @config.process_id = Process.pid
      end
      @config
    end

    def configure
      yield config
    end

    private

    def check_configured
      raise UnconfiguredError, "redis must be configured" unless config.redis
    end

    def generate_owner
      "#{config.hostname}:#{config.process_id}:#{Thread.current.object_id}"
    end
  end
end

require 'master_lock/redis_lock'
require 'master_lock/registry'
