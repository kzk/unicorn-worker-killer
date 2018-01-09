module Unicorn
  module WorkerKiller
    module Oom
      include Randomize

      # Killing the process must be occurred at the outside of the request. We're
      # using similar techniques used by OobGC, to ensure actual killing doesn't
      # affect the request.
      #
      # @see https://github.com/defunkt/unicorn/blob/master/lib/unicorn/oob_gc.rb#L40
      def self.new(app, memory_limit_min = (1024 ** 3), memory_limit_max = (2 * (1024 ** 3)), check_cycle = 16, verbose = false)
        ObjectSpace.each_object(Unicorn::HttpServer) do |s|
          s.extend(self)
          s.instance_variable_set(:@_worker_memory_limit_min, memory_limit_min)
          s.instance_variable_set(:@_worker_memory_limit_max, memory_limit_max)
          s.instance_variable_set(:@_worker_check_cycle, check_cycle)
          s.instance_variable_set(:@_worker_check_count, 0)
          s.instance_variable_set(:@_verbose, verbose)
        end

        app # pretend to be Rack middleware since it was in the past
      end

      def process_client(client)
        super(client) # Unicorn::HttpServer#process_client

        return if @_worker_memory_limit_min == 0 && @_worker_memory_limit_max == 0

        @_worker_process_start ||= Time.now
        @_worker_memory_limit  ||= @_worker_memory_limit_min + randomize(@_worker_memory_limit_max - @_worker_memory_limit_min + 1)
        @_worker_check_count   += 1

        return unless @_worker_check_count % @_worker_check_cycle == 0

        bytes_used = GetProcessMem.new.bytes

        logger.info "#{self}: worker (pid: #{Process.pid}) using #{bytes_used} bytes." if @_verbose

        if bytes_used > @_worker_memory_limit
          logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds memory limit (#{bytes_used} bytes > #{@_worker_memory_limit} bytes)"

          Unicorn::WorkerKiller.kill_self(logger, @_worker_process_start)
        end

        @_worker_check_count = 0
      end
    end
  end
end
