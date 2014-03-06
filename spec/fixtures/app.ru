$:.unshift File.expand_path "../../../lib", __FILE__
require "rack"
require "rack/server"
require "unicorn_worker_killer"

UnicornWorkerKiller.configure do |config|
  if ram = ENV["UNICORN_WORKER_MEMORY"]
    config.ram = Integer(ram)
  end

  if memory_check_frequency = ENV["UNICORN_WORKER_MEMORY_CHECK_FREQUENCY"]
    config.memory_check_frequency = Integer(memory_check_frequency)
  end
end
UnicornWorkerKiller.start

class HelloWorld
  DUMP = ""

  def response
    DUMP << "." * 1048576 # 1MB of dots
    [200, {}, ["#{DUMP.bytes.length}"]]
  end
end

class HelloWorldApp
  def self.call(env)
    HelloWorld.new.response
  end
end

run HelloWorldApp
