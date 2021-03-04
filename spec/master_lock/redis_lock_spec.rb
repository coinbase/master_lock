require 'spec_helper'

RSpec.describe MasterLock::RedisLock, redis: true, cluster: true do
  let(:redis_backend) do
    b = MasterLock::Backend.new
    b.configure do |config|
      config.redis = redis
      config.cluster = false
    end
    b
  end
  let(:cluster_backend) do
    b = MasterLock::Backend.new
    b.configure do |config|
      config.redis = cluster
      config.cluster = true
    end
    b
  end

  let(:lock1) do
    described_class.new(config: redis_backend.config, key: "key", owner: "owner1", ttl: 0.1)
  end
  let(:lock2) do
    described_class.new(config: redis_backend.config, key: "key", owner: "owner2", ttl: 0.1)
  end
  let(:lock3) do
    described_class.new(config: cluster_backend.config, key: "key", owner: "owner3", ttl: 0.1)
  end
  let(:lock4) do
    described_class.new(config: cluster_backend.config, key: "key", owner: "owner4", ttl: 0.1)
  end

  before do
    clean_redis
    clean_cluster
  end

  describe "#redis basic tests" do
    it "starts empty and then works" do
      expect(redis.mget('{key}1', '{key}2')).to eq([nil, nil])
      expect {redis.set('{key}1', 'a')}.to_not raise_error
      expect {redis.set('{key}2', 'b')}.to_not raise_error
      expect {redis.set('{key}1', 'c')}.to_not raise_error
      expect(redis.mget('{key}1', '{key}2')).to eq(['c', 'b'])
    end
  end

  describe "#cluster basic tests" do
    it "starts empty and then works" do
      expect(cluster.mget('{key}1', '{key}2')).to eq([nil, nil])
      expect {cluster.set('{key}1', 'a')}.to_not raise_error
      expect {cluster.set('{key}2', 'b')}.to_not raise_error
      expect {cluster.set('{key}1', 'c')}.to_not raise_error
      expect(cluster.mget('{key}1', '{key}2')).to eq(['c', 'b'])
    end
  end

  describe "#acquire" do
    it "returns true when lock can be acquired" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(redis.get('masterlock:key')).to_not be_nil
      # Cluster test
      expect(lock3.acquire(timeout: 0)).to eq(true)
      expect(cluster.get('masterlock:key')).to_not be_nil
    end

    it "returns false when lock can not be acquired" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(lock2.acquire(timeout: 0)).to eq(false)
      # Cluster test
      expect(lock3.acquire(timeout: 0)).to eq(true)
      expect(lock4.acquire(timeout: 0)).to eq(false)
    end

    it "returns false if the same owner already has the lock" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(lock1.acquire(timeout: 0)).to eq(false)
      # Cluster test
      expect(lock3.acquire(timeout: 0)).to eq(true)
      expect(lock3.acquire(timeout: 0)).to eq(false)
    end

    it "attempts to acquire the lock repeatedly until timeout" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(lock2.acquire(timeout: 1)).to eq(true)
      # Cluster test
      expect(lock3.acquire(timeout: 0)).to eq(true)
      expect(lock4.acquire(timeout: 1)).to eq(true)
    end
  end

  describe "#extend" do
    it "returns true when lock is held by owner" do
      lock1.acquire(timeout: 0)
      expect(lock1.extend).to eq(true)
      # Cluster test
      lock3.acquire(timeout: 0)
      expect(lock3.extend).to eq(true)
    end

    it "returns false when lock is held by another owner" do
      lock2.acquire(timeout: 0)
      expect(lock1.extend).to eq(false)
      # Cluster test
      lock4.acquire(timeout: 0)
      expect(lock3.extend).to eq(false)
    end

    it "returns false when lock is not held" do
      expect(lock1.extend).to eq(false)
      # Cluster test
      expect(lock3.extend).to eq(false)
    end

    it "resets the expiration time" do
      lock1.acquire(timeout: 0)
      3.times do
        sleep 0.05
        expect(lock1.extend).to eq(true)
      end
      sleep 0.2
      expect(lock1.extend).to eq(false)
      # Cluster test
      lock3.acquire(timeout: 0)
      3.times do
        sleep 0.05
        expect(lock3.extend).to eq(true)
      end
      sleep 0.2
      expect(lock3.extend).to eq(false)
    end
  end

  describe "#release" do
    it "returns true when lock is held by owner" do
      lock1.acquire(timeout: 0)
      expect(redis.get('masterlock:key')).to_not be_nil
      expect(lock1.release).to eq(true)
      expect(redis.get('masterlock:key')).to be_nil
      # Cluster test
      lock3.acquire(timeout: 0)
      expect(cluster.get('masterlock:key')).to_not be_nil
      expect(lock3.release).to eq(true)
      expect(cluster.get('masterlock:key')).to be_nil
    end

    it "returns false when lock is held by another owner" do
      lock2.acquire(timeout: 0)
      expect(lock1.release).to eq(false)
      expect(redis.get('masterlock:key')).to_not be_nil
      # Cluster test
      lock4.acquire(timeout: 0)
      expect(lock3.release).to eq(false)
      expect(cluster.get('masterlock:key')).to_not be_nil
    end

    it "returns false when lock is not held" do
      expect(lock1.release).to eq(false)
      # Cluster test
      expect(lock3.release).to eq(false)
    end

    it "changes the lock to be unowned" do
      lock1.acquire(timeout: 0)
      expect(lock1.release).to eq(true)
      expect(lock1.release).to eq(false)
      expect(lock2.acquire(timeout: 0)).to eq(true)
      # Cluster test
      lock3.acquire(timeout: 0)
      expect(lock3.release).to eq(true)
      expect(lock3.release).to eq(false)
      expect(lock4.acquire(timeout: 0)).to eq(true)
    end
  end
end
