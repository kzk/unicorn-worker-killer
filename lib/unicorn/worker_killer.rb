require 'unicorn/configuration'
require 'get_process_mem'

module Unicorn::WorkerKiller
  class << self
    attr_accessor :configuration
  end

  # Kill the current process by telling it to send signals to itself. If
  # the process isn't killed after `configuration.max_quit` QUIT signals,
  # send TERM signals until `configuration.max_term`. Finally, send a KILL
  # signal. A single signal is sent per request.
  # @see http://unicorn.bogomips.org/SIGNALS.html
  def self.kill_self(logger, start_time, first_signal=:QUIT)
    alive_sec = (Time.now - start_time).round
    worker_pid = Process.pid

    @@kill_attempts ||= 0
    @@kill_attempts += 1

    sig = first_signal
    sig = :TERM if @@kill_attempts > configuration.max_quit
    sig = :KILL if @@kill_attempts > configuration.max_term

    logger.warn "#{self} send SIG#{sig} (pid: #{worker_pid}) alive: #{alive_sec} sec (trial #{@@kill_attempts})"
    Process.kill sig, worker_pid
  end

  module Oom
    # Killing the process must be occurred at the outside of the request. We're
    # using similar techniques used by OobGC, to ensure actual killing doesn't
    # affect the request.
    #
    # @see https://github.com/defunkt/unicorn/blob/master/lib/unicorn/oob_gc.rb#L40
    def self.new(app, memory_limit_min = (1024**3), memory_limit_max = (2*(1024**3)), check_cycle = 16, verbose = false, object_space_dump=false)
      ObjectSpace.each_object(Unicorn::HttpServer) do |s|
        s.extend(self)
        s.instance_variable_set(:@_worker_memory_limit_min, memory_limit_min)
        s.instance_variable_set(:@_worker_memory_limit_max, memory_limit_max)
        s.instance_variable_set(:@_worker_check_cycle, check_cycle)
        s.instance_variable_set(:@_worker_check_count, 0)
        s.instance_variable_set(:@_verbose, verbose)
        s.instance_variable_set(:@_object_space_dump, object_space_dump)
      end
      if object_space_dump
        require 'objspace'
        trap_sigabrt
      end
      app # pretend to be Rack middleware since it was in the past
    end

    def randomize(integer)
      RUBY_VERSION > "1.9" ? Random.rand(integer.abs) : rand(integer)
    end

    def process_client(client)
      super(client) # Unicorn::HttpServer#process_client
      return if @_worker_memory_limit_min == 0 && @_worker_memory_limit_max == 0

      @_worker_process_start ||= Time.now
      @_worker_memory_limit ||= @_worker_memory_limit_min + randomize(@_worker_memory_limit_max - @_worker_memory_limit_min + 1)
      @_worker_check_count += 1
      if @_worker_check_count % @_worker_check_cycle == 0
        rss = GetProcessMem.new.bytes
        logger.info "#{self}: worker (pid: #{Process.pid}) using #{rss} bytes." if @_verbose
        if rss > @_worker_memory_limit
          logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds memory limit (#{rss} bytes > #{@_worker_memory_limit} bytes)"
          first_signal = @_object_space_dump ? :SIGABRT : :QUIT
          Unicorn::WorkerKiller.kill_self(logger, @_worker_process_start, first_signal)
        end
        @_worker_check_count = 0
      end
    end

    def self.trap_sigabrt
      trap(:SIGABRT) do
        if lock_for_dump
          dump_file = Unicorn::WorkerKiller.configuration.object_space_dump_file.gsub(/\$PID/, Process.pid.to_s)
          GC.start
          ObjectSpace.dump_all(output: File.open(dump_file, 'w'))
          release_lock_for_dump
        end
        Process.kill(:QUIT, Process.pid)
      end
    end

    def self.lock_for_dump
      @lock_for_dump_file = File.open(Unicorn::WorkerKiller.configuration.object_space_dump_lock, File::RDWR|File::CREAT, 0644)
      @lock_for_dump_file.flock(File::LOCK_NB|File::LOCK_EX)
    end

    def self.release_lock_for_dump
      @lock_for_dump_file.close
    end
  end

  module MaxRequests
    # Killing the process must be occurred at the outside of the request. We're
    # using similar techniques used by OobGC, to ensure actual killing doesn't
    # affect the request.
    #
    # @see https://github.com/defunkt/unicorn/blob/master/lib/unicorn/oob_gc.rb#L40
    def self.new(app, max_requests_min = 3072, max_requests_max = 4096, verbose = false)
      ObjectSpace.each_object(Unicorn::HttpServer) do |s|
        s.extend(self)
        s.instance_variable_set(:@_worker_max_requests_min, max_requests_min)
        s.instance_variable_set(:@_worker_max_requests_max, max_requests_max)
        s.instance_variable_set(:@_verbose, verbose)
      end

      app # pretend to be Rack middleware since it was in the past
    end

    def randomize(integer)
      RUBY_VERSION > "1.9" ? Random.rand(integer.abs) : rand(integer)
    end

    def process_client(client)
      super(client) # Unicorn::HttpServer#process_client
      return if @_worker_max_requests_min == 0 && @_worker_max_requests_max == 0

      @_worker_process_start ||= Time.now
      @_worker_cur_requests ||= @_worker_max_requests_min + randomize(@_worker_max_requests_max - @_worker_max_requests_min + 1)
      @_worker_max_requests ||= @_worker_cur_requests
      logger.info "#{self}: worker (pid: #{Process.pid}) has #{@_worker_cur_requests} left before being killed" if @_verbose

      if (@_worker_cur_requests -= 1) <= 0
        logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds max number of requests (limit: #{@_worker_max_requests})"
        Unicorn::WorkerKiller.kill_self(logger, @_worker_process_start)
      end
    end
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  self.configure
end
