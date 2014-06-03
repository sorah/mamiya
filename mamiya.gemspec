# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mamiya/version'

Gem::Specification.new do |spec|
  spec.name          = "mamiya"
  spec.version       = Mamiya::VERSION
  spec.authors       = ["Shota Fukumori (sora_h)"]
  spec.email         = ["her@sorah.jp"]
  spec.summary       = %q{Fast deploy tool using tarballs and serf}
  spec.description   = %q{Deploy tool using tarballs and serf for lot of servers}
  spec.homepage      = "https://github.com/sorah/mamiya"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "thor", "~> 0.18.1"
  spec.add_runtime_dependency "aws-sdk-core", "2.0.0.rc6"
  spec.add_runtime_dependency "term-ansicolor", ">= 1.3.0"
  unless ENV["MAMIYA_VILLEIN_PATH"]
    spec.add_runtime_dependency "villein", ">= 0.3.1"
  end

  spec.add_runtime_dependency "sinatra", ">= 1.4.5"

  spec.add_development_dependency "rspec", "2.14.1"
  spec.add_development_dependency 'rack-test', '~> 0.6.2'

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency 'simplecov', '~> 0.7.1'
end
