lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'master_lock/version'

Gem::Specification.new do |spec|
  spec.name          = "master_lock"
  spec.version       = MasterLock::VERSION
  spec.authors       = ["Jim Posen"]
  spec.email         = ["jimpo@coinbase.com"]

  spec.summary       = "Inter-process locking library using Redis."
  spec.description   = "This library implements application mutexes using Redis. The mutexes are " \
                       "shared between separate threads, processes, or machines. Locks are acquired " \
                       "with an expiration time so if process that holds a lock dies unexpectedly, " \
                       "the lock is released automatically after a certain duration."
  spec.homepage      = "https://github.com/coinbase/master_lock"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(/^spec/) }
  spec.require_paths = ["lib"]

  spec.add_dependency "redis", ">= 3.0", "< 5"
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", ">= 12.3.3"
  spec.add_development_dependency "rspec", "~> 3.0"
end
