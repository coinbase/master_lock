require 'spec_helper'

RSpec.describe MasterLock::Registry do
  subject(:registry) { described_class.new }
  let(:lock) { instance_double('MasterLock::RedisLock', key: 'test') }

  describe "#register" do
    it "returns the registered struct" do
      registration = registry.register(lock, 1)
      expect(registration.lock).to eq(lock)
      expect(registration.extend_interval).to eq(1)
      expect(registration.thread).to eq(Thread.current)
      expect(registration.released).to eq(false)
    end

    it "tracks the registered lock" do
      expect { registry.register(lock, 1) }
        .to change(registry.locks, :size).by(1)
    end
  end

  describe "#unregister" do
    it "marks the lock as released" do
      registration = registry.register(lock, 1)
      expect(registration.released).to eq(false)

      registry.unregister(registration)
      expect(registration.released).to eq(true)
    end
  end

  describe "#extend_locks" do
    let!(:registration) { registry.register(lock, 1) }

    it "does not remove active locks" do
      expect { registry.extend_locks }.to_not change(registry.locks, :size)
    end

    it "does not attempt to extend recently acquired locks" do
      expect(lock).to_not receive(:extend)
      registry.extend_locks
    end

    it "extends locks that have been held longer than the extend_interval" do
      old_acquired_at = registration.acquired_at = Time.now - 2
      expect(lock).to receive(:extend).and_return(true)

      registry.extend_locks
      expect(registration.acquired_at).to be > old_acquired_at
    end

    it "removes the locks from the registered list after it has been released" do
      registration.released = true
      expect { registry.extend_locks }.to change(registry.locks, :size).by(-1)
    end

    it "removes the locks from the registered list after it has expired" do
      registration.acquired_at = Time.now - 2
      expect(lock).to receive(:extend).and_return(false)

      expect { registry.extend_locks }.to change(registry.locks, :size).by(-1)
      expect(registration.released).to eq(true)
    end
  end
end
