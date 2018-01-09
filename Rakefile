require 'bundler'
require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

Bundler::GemHelper.install_tasks
RSpec::Core::RakeTask.new(:spec)

task :default => [:build]
