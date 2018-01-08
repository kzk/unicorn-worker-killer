# encoding: utf-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'unicorn/worker_killer/version'

Gem::Specification.new do |s|
  s.name    = 'unicorn-worker-killer'
  s.version = Unicorn::WorkerKiller::VERSION
  s.authors = ['Kazuki Ohta', 'Sadayuki Furuhashi', 'Jonathan Clem']
  s.email   = ['kazuki.ohta@gmail.com', 'frsyuki@gmail.com', 'jonathan@jclem.net']

  s.homepage    = 'https://github.com/kzk/unicorn-worker-killer'
  s.description = 'Kill unicorn workers by memory and request counts'
  s.summary     = s.description
  s.licenses    = ['GPLv2+', 'Ruby 1.8']

  s.files      = `git ls-files`.split("\n")
  s.test_files = `git ls-files -- spec/*`.split("\n")

  s.add_dependency 'unicorn', ['>= 4', '< 6']
  s.add_dependency 'get_process_mem', '~> 0'

  s.add_development_dependency 'rake', '>= 0.9.2'
  s.add_development_dependency 'rspec'
end
