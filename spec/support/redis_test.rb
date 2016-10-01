require 'redis'

module RedisTest
  REDIS_URL = ENV['REDIS_URL'] || "redis://127.0.0.1:6379/0"

  def redis
    @redis ||= Redis.new(url: REDIS_URL)
  end
end
