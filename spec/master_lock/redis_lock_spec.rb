require 'spec_helper'

RSpec.describe MasterLock::RedisLock, redis: true do
  let(:lock1) do
    described_class.new(redis: redis, key: "key", owner: "owner1", ttl: 0.1)
  end
  let(:lock2) do
    described_class.new(redis: redis, key: "key", owner: "owner2", ttl: 0.1)
  end

  describe "#acquire" do
    it "returns true when lock can be acquired" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
    end

    it "returns false when lock can not be acquired" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(lock2.acquire(timeout: 0)).to eq(false)
    end

    it "returns false if the same owner already has the lock" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(lock1.acquire(timeout: 0)).to eq(false)
    end

    it "attempts to acquire the lock repeatedly until timeout" do
      expect(lock1.acquire(timeout: 0)).to eq(true)
      expect(lock2.acquire(timeout: 1)).to eq(true)
    end
  end

  describe "#extend" do
    it "returns true when lock is held by owner" do
      lock1.acquire(timeout: 0)
      expect(lock1.extend).to eq(true)
    end

    it "returns false when lock is held by another owner" do
      lock2.acquire(timeout: 0)
      expect(lock1.extend).to eq(false)
    end

    it "returns false when lock is not held" do
      expect(lock1.extend).to eq(false)
    end

    it "resets the expiration time" do
      lock1.acquire(timeout: 0)
      3.times do
        sleep 0.05
        expect(lock1.extend).to eq(true)
      end
      sleep 0.2
      expect(lock1.extend).to eq(false)
    end
  end

  describe "#release" do
    it "returns true when lock is held by owner" do
      lock1.acquire(timeout: 0)
      expect(lock1.release).to eq(true)
    end

    it "returns false when lock is held by another owner" do
      lock2.acquire(timeout: 0)
      expect(lock1.release).to eq(false)
    end

    it "returns false when lock is not held" do
      expect(lock1.release).to eq(false)
    end

    it "changes the lock to be unowned" do
      lock1.acquire(timeout: 0)
      expect(lock1.release).to eq(true)
      expect(lock1.release).to eq(false)
      expect(lock2.acquire(timeout: 0)).to eq(true)
    end
  end
end
