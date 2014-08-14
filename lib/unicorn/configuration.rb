module Unicorn::WorkerKiller
  class Configuration
    attr_accessor :max_quit, :max_term, :sleep_interval, :object_space_dump_file, :object_space_dump_lock

    def initialize
      self.max_quit = 10
      self.max_term = 15
      self.sleep_interval = 1
      self.object_space_dump_file = '/tmp/unicorn_worker_$PID.json'
      self.object_space_dump_lock = '/tmp/unicorn_worker_dump.lock'
    end
  end
end
