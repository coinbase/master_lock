require 'redis'

module RedisTest
  REDIS_URL = ENV['REDIS_URI'] || "redis://127.0.0.1:6379"

  def redis
    @redis ||= Redis.new(url: REDIS_URL)
  end

  def clean_redis
    redis.flushdb
    redis.script(:flush)
  end
end
