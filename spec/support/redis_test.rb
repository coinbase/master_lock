require 'redis'

module RedisTest
  REDIS_URL = ENV['REDIS_URI'] || "redis://127.0.0.1:6379"

  def redis
    @redis ||= Redis.new(url: REDIS_URL)
  end

  def cluster
    nodes = (7000..7005).map { |port| "redis://127.0.0.1:#{port}" }
    @cluster ||= Redis.new(cluster: nodes)
  end

  def clean_redis
    redis.flushdb
    redis.script(:flush)
  end

  def clean_cluster
    cluster.flushdb
    cluster.script(:flush)
  end
end
