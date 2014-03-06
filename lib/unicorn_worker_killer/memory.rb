module UnicornWorkerKiller
  module Memory
    class << self
      attr_reader :is_configured
      attr_reader :max_worker_ram
    end

    def self.activate!
      UnicornWorkerKiller::ProcessClient.include(ReapOnMemory)
    end

    def self.setup(max_worker_ram)
      @is_configured  = true
      @max_worker_ram = max_worker_ram
    end

    def self.memory_check_frequency
      @memory_check_frequency ||= 1
    end

    def self.memory_check_frequency=(val)
      @memory_check_frequency = val
    end

    module ReapOnMemory
      def unicorn_worker_killer_reap_on_memory
        @unicorn_worker_killer_memory_check_count ||= 0
        @unicorn_worker_killer_memory_check_count += 1

        if @unicorn_worker_killer_memory_check_count % Memory.memory_check_frequency == 0
          if GetProcessMem.new.bytes > Memory.max_worker_ram * 1024 * 1024
            Process.kill :QUIT, Process.pid
          end
        end
      end
    end
  end
end
