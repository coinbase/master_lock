module MasterLock
  # When MasterLock acquires a lock, it registers it with a global registry.
  # MasterLock will periodically renew all locks that are registered as long as
  # the thread that acquired the lock is still alive and has not explicitly
  # released the lock yet. If there is a failure to renew the lock, MasterLock
  # identifies the lock as having already been released.
  class Registry
    Registration = Struct.new(
      :lock,
      :mutex,
      :thread,
      :acquired_at,
      :released,
      :extend_interval
    )

    # @return [Array<Registration>] currently registered locks
    attr_reader :locks

    def initialize
      @locks = []
      @locks_mutex = Mutex.new
    end

    # Register a lock to be renewed every extend_interval seconds.
    #
    # @param lock [#extend] a currently held lock that can be extended
    # @param extend_interval [Fixnum] the interval in seconds after before the
    #   lock is extended
    # @return [Registration] the receipt of registration
    def register(lock, extend_interval)
      registration = Registration.new
      registration.lock = lock
      registration.mutex = Mutex.new
      registration.thread = Thread.current
      registration.acquired_at = Time.now
      registration.extend_interval = extend_interval
      registration.released = false
      @locks_mutex.synchronize do
        locks << registration
      end
      registration
    end

    # Unregister a lock that has been registered.
    #
    # @param registration [Registration] the registration returned by the call
    #   to {#register}
    def unregister(registration)
      registration.mutex.synchronize do
        registration.released = true
      end
    end

    # Extend all currently registered locks that have been held longer than the
    # extend_interval since they were last acquired/extended. If any locks have
    # expired (should not happen), it will release them.
    def extend_locks
      # Make a local copy of the locks array to avoid accessing it outside of the mutex.
      locks_copy = @locks_mutex.synchronize { locks.dup }
      locks_copy.each { |registration| extend_lock(registration) }
      @locks_mutex.synchronize do
        locks.delete_if(&:released)
      end
    end

    private

    def extend_lock(registration)
      registration.mutex.synchronize do
        time = Time.now
        if !registration.thread.alive?
          registration.released = true
        elsif !registration.released &&
            registration.acquired_at + registration.extend_interval < time
          if registration.lock.extend
            registration.acquired_at = time
          else
            registration.released = true
            # TODO: Notify of failure somehow
          end
        end
      end
    end
  end
end
