# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife-container/version'

Gem::Specification.new do |spec|
  spec.name          = "knife-container"
  spec.version       = Knife::Container::VERSION
  spec.authors       = ["Tom Duffield"]
  spec.email         = ["tom@getchef.com"]
  spec.summary       = %q{Docker support for Chef's Knife Command}
  spec.description   = spec.summary
  spec.homepage      = "http://github.com/opscode/knife-container"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "chef", ">= 11.0.0"
  spec.add_development_dependency "mixlib-config", "~> 2.0"
end
