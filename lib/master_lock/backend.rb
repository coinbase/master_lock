module MasterLock
  class Backend

    # Obtain a mutex around a critical section of code. Only one thread on any
    # machine can execute the given block at a time. Returns the result of the
    # block.
    #
    # @param key [String] the unique identifier for the locked resource
    # @option options [Fixnum] :ttl (60) the length of time in seconds before
    #   the lock expires
    # @option options [Fixnum] :acquire_timeout (5) the length of time to wait
    #   to acquire the lock before timing out
    # @option options [Fixnum] :extend_interval (15) the amount of time in
    #   seconds that may pass before extending the lock
    # @option options [Boolean] :if if this option is falsey, the block will be
    #   executed without obtaining the lock
    # @option options [Boolean] :unless if this option is truthy, the block will
    #   be executed without obtaining the lock
    # @raise [UnconfiguredError] if a required configuration variable is unset
    # @raise [NotStartedError] if called before {#start}
    # @raise [LockNotAcquiredError] if the lock cannot be acquired before the
    #   timeout
    def synchronize(key, options = {})
      check_configured
      raise NotStartedError unless @registry

      ttl = options[:ttl] || config.ttl
      acquire_timeout = options[:acquire_timeout] || config.acquire_timeout
      extend_interval = options[:extend_interval] || config.extend_interval

      raise ArgumentError, "extend_interval cannot be negative" if extend_interval < 0
      raise ArgumentError, "ttl must be greater extend_interval" if ttl <= extend_interval

      if (options.include?(:if) && !options[:if]) ||
          (options.include?(:unless) && options[:unless])
        return yield
      end

      lock = RedisLock.new(
          config: config,
          key: key,
          ttl: ttl,
          owner: generate_owner
      )
      if !lock.acquire(timeout: acquire_timeout)
        raise LockNotAcquiredError, key
      end

      registration =
          @registry.register(lock, extend_interval)
      logger.debug("Acquired lock #{key}")
      begin
        yield
      ensure
        @registry.unregister(registration)
        if lock.release
          logger.debug("Released lock #{key}")
        else
          logger.warn("Failed to release lock #{key}")
        end
      end
    end

    # Starts the background thread to manage and extend currently held locks.
    # The thread remains alive for the lifetime of the process. This must be
    # called before any locks may be acquired.
    def start
      @registry = Registry.new
      Thread.new do
        loop do
          @registry.extend_locks
          sleep(config.sleep_time)
        end
      end
    end

    # Returns true if the registry has been started, otherwise false
    # @return [Boolean]
    def started?
      !@registry.nil?
    end

    # Get the configured logger.
    #
    # @return [Logger]
    def logger
      config.logger
    end

    # @return [Config] MasterLock configuration settings
    def config
      if !defined?(@config)
        @config = Config.new
        @config.acquire_timeout = DEFAULT_ACQUIRE_TIMEOUT
        @config.extend_interval = DEFAULT_EXTEND_INTERVAL
        @config.hostname = Socket.gethostname
        @config.logger = Logger.new(STDOUT)
        @config.logger.progname = 'MasterLock'
        @config.key_prefix = DEFAULT_KEY_PREFIX
        @config.sleep_time = DEFAULT_SLEEP_TIME
        @config.ttl = DEFAULT_TTL
        @config.cluster = false
      end
      @config
    end

    # Configure MasterLock using block syntax. Simply yields {#config} to the
    # block.
    #
    # @yield [Config] the configuration
    def configure
      yield config
    end

    private

    def check_configured
      raise UnconfiguredError, "redis must be configured" unless config.redis
    end

    def generate_owner
      "#{config.hostname}:#{Process.pid}:#{Thread.current.object_id}"
    end
  end
end