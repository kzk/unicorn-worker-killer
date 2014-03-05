# encoding: utf-8
$:.push File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.name        = "unicorn-worker-killer"
  gem.version     = File.read("VERSION").strip
  gem.authors     = ["Kazuki Ohta", "Sadayuki Furuhashi", "Jonathan Clem"]
  gem.email       = ["kazuki.ohta@gmail.com", "frsyuki@gmail.com", "jonathan@jclem.net"]
  gem.description = "Kill unicorn workers according to memory and request count"
  gem.summary     = "Monitory request count and memory usage of unicorn workers, and kill them appropriately"
  gem.homepage    = "https://github.com/kzk/unicorn-worker-killer"
  gem.license     = "MIT"

  gem.files       = `git ls-files`.split("\n")
  gem.test_files  = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_dependency "unicorn",         "~> 4"
  gem.add_dependency "get_process_mem", "~> 0"
  gem.add_development_dependency "rake", "~> 10.1"
end
