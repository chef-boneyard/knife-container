require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = [].tap do |a|
    a.push('--color')
    a.push('--format doc')
  end.join(' ')
end

desc 'Run all tests'
task :test => [:spec]


task :default => [:test]
