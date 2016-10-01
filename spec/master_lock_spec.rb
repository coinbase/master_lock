require "spec_helper"

RSpec.describe MasterLock do
  it "has a version number" do
    expect(MasterLock::VERSION).not_to be nil
  end
end
