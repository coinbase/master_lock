require 'digest/sha1'

module MasterLock
  module RedisScripts
    RELEASE_SCRIPT = <<EOS
if redis.call("GET", KEYS[1]) == ARGV[1]
then
    return redis.call("DEL", KEYS[1])
else
    return 0
end
EOS
    RELEASE_SCRIPT_HASH = Digest::SHA1.hexdigest(RELEASE_SCRIPT)

    EXTEND_SCRIPT = <<EOS
if redis.call("GET", KEYS[1]) == ARGV[1]
then
    return redis.call("PEXPIRE", KEYS[1], tonumber(ARGV[2]))
else
    return 0
end
EOS
    EXTEND_SCRIPT_HASH = Digest::SHA1.hexdigest(EXTEND_SCRIPT)
  end
end
