# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'knife-container/version'

Gem::Specification.new do |spec|
  spec.name          = 'knife-container'
  spec.version       = Knife::Container::VERSION
  spec.authors       = ['Tom Duffield']
  spec.email         = ['tom@getchef.com']
  spec.summary       = %q(Container support for Chef's Knife Command)
  spec.description   = spec.summary
  spec.homepage      = 'http://github.com/opscode/knife-container'
  spec.license       = 'Apache 2.0'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.0'

  spec.add_dependency 'chef', '>= 11.16.0'
  spec.add_dependency 'docker-api', '~> 1.11.1'
  spec.add_dependency 'json', '>= 1.4.4', '<= 1.8.2'

  %w(rspec-core rspec-expectations rspec-mocks).each { |gem| spec.add_development_dependency gem, '~> 2.14.0' }
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'rake', '~> 10.1.0'
  spec.add_development_dependency 'pry'
end
