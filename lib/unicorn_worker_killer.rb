require 'get_process_mem'
require 'unicorn'
require 'unicorn_worker_killer/process_client'
require 'unicorn_worker_killer/memory'
require 'unicorn_worker_killer/version'

module UnicornWorkerKiller
  def self.configure
    yield self
  end

  def self.start
    Memory.activate! if Memory.is_configured
    ObjectSpace.each_object(Unicorn::HttpServer) do |worker|
      worker.extend(ProcessClient)
    end
  end

  def self.ram=(ram)
    Memory.setup(ram)
  end

  def self.memory_check_frequency=(n_reqs)
    Memory.memory_check_frequency = n_reqs
  end
end
