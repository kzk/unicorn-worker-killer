require 'unicorn'
require 'unicorn/worker_killer/configuration'
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
  def self.kill_self(logger, start_time)
    alive_sec = (Time.now - start_time).round
    worker_pid = Process.pid

    @@kill_attempts ||= 0
    @@kill_attempts += 1

    sig = :QUIT
    sig = :TERM if @@kill_attempts > configuration.max_quit
    sig = :KILL if @@kill_attempts > configuration.max_term

    logger.warn "#{self} send SIG#{sig} (pid: #{worker_pid}) alive: #{alive_sec} sec (trial #{@@kill_attempts})"
    Process.kill sig, worker_pid
  end

  def self.randomize(integer)
    RUBY_VERSION > "1.9" ? Random.rand(integer.abs) : rand(integer)
  end

  module Oom
    # Killing the process must be occurred at the outside of the request. We're
    # using similar techniques used by OobGC, to ensure actual killing doesn't
    # affect the request.
    #
    # @see https://github.com/defunkt/unicorn/blob/master/lib/unicorn/oob_gc.rb#L40
    def self.new(app, memory_limit_min = (1024**3), memory_limit_max = (2*(1024**3)), check_cycle = 32, verbose = false)
      @@servers ||= []
      if @@servers.empty?
        ObjectSpace.each_object(Unicorn::HttpServer) do |s|
          @@servers << s
        end
      end
      
      @@servers.each do |s|
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
      
      memory_limit_min = @_worker_memory_limit_min
      memory_limit_max = @_worker_memory_limit_max
      return if memory_limit_min == 0 && memory_limit_max == 0

      @_worker_process_start ||= Time.now
      @_worker_memory_limit ||= memory_limit_min + Unicorn::WorkerKiller.randomize(memory_limit_max - memory_limit_min + 1)
      @_worker_check_count += 1
      check_cycle = @_worker_check_cycle
      if @_worker_check_count % check_cycle == 0
        @@process_mem ||= GetProcessMem.new
        rss = @@process_mem.bytes
        logger.info "#{self}: worker (pid: #{Process.pid}) using #{rss} bytes." if @_verbose
        memory_limit = @_worker_memory_limit
        if rss > memory_limit
          logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds memory limit (#{rss} bytes > #{memory_limit} bytes)"
          Unicorn::WorkerKiller.kill_self(logger, @_worker_process_start)
        end
        @_worker_check_count = 0
      end
    end
  end

  module MaxRequests
    # Killing the process must be occurred at the outside of the request. We're
    # using similar techniques used by OobGC, to ensure actual killing doesn't
    # affect the request.
    #
    # @see https://github.com/defunkt/unicorn/blob/master/lib/unicorn/oob_gc.rb#L40
    def self.new(app, max_requests_min = 3072, max_requests_max = 4096, verbose = false)
      @@servers ||= []
      if @@servers.empty?
        ObjectSpace.each_object(Unicorn::HttpServer) do |s|
          @@servers << s
        end
      end
      
      @@servers.each do |s|
        s.extend(self)
        s.instance_variable_set(:@_worker_max_requests_min, max_requests_min)
        s.instance_variable_set(:@_worker_max_requests_max, max_requests_max)
        s.instance_variable_set(:@_verbose, verbose)
      end

      app # pretend to be Rack middleware since it was in the past
    end


    def process_client(client)
      super(client) # Unicorn::HttpServer#process_client
      
      max_requests_min = @_worker_max_requests_min
      max_requests_max = @_worker_max_requests_max
      return if max_requests_min == 0 && max_requests_max == 0

      @_worker_process_start ||= Time.now
      @_worker_cur_requests ||= max_requests_min + Unicorn::WorkerKiller.randomize(max_requests_max - max_requests_min + 1)
      @_worker_max_requests ||= @_worker_cur_requests
      cur_requests = @_worker_cur_requests
      logger.info "#{self}: worker (pid: #{Process.pid}) has #{cur_requests} left before being killed" if @_verbose

      if (@_worker_cur_requests -= 1) <= 0
        max_requests = @_worker_max_requests
        logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds max number of requests (limit: #{max_requests})"
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
