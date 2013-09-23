require 'unicorn/configuration'

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

  module Oom
    # Killing the process must be occurred at the outside of the request. We're
    # using similar techniques used by OobGC, to ensure actual killing doesn't
    # affect the request.
    #
    # @see https://github.com/defunkt/unicorn/blob/master/lib/unicorn/oob_gc.rb#L40
    def self.new(app, memory_limit_min = (1024**3), memory_limit_max = (2*(1024**3)), check_cycle = 16, verbose = false)
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

    def randomize(integer)
      RUBY_VERSION > "1.9" ? Random.rand(integer) : rand(integer)
    end

    def process_client(client)
      super(client) # Unicorn::HttpServer#process_client
      return if @_worker_memory_limit_min == 0 && @_worker_memory_limit_max == 0

      @_worker_process_start ||= Time.now
      @_worker_memory_limit ||= @_worker_memory_limit_min + randomize(@_worker_memory_limit_max - @_worker_memory_limit_min + 1)
      @_worker_check_count += 1

      if @_worker_check_count % @_worker_check_cycle == 0
        rss = _worker_rss()
        logger.info "#{self}: worker (pid: #{Process.pid}) using #{rss} bytes." if @_verbose
        if rss > @_worker_memory_limit
          logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds memory limit (#{rss} bytes > #{@_worker_memory_limit} bytes)"
          Unicorn::WorkerKiller.kill_self(logger, @_worker_process_start)
        end
        @_worker_check_count = 0
      end
    end

    private

    def _worker_rss
      proc_status = "/proc/#{Process.pid}/status"
      if File.exists? proc_status
        open(proc_status).each_line { |l|
          if l.include? 'VmRSS'
            ls = l.split
            if ls.length == 3
              value = ls[1].to_i
              unit = ls[2]
              case unit.downcase
              when 'kb'
                return value*(1024**1)
              when 'mb'
                return value*(1024**2)
              when 'gb'
                return value*(1024**3)
              end
            end
          end
        }
      end

      # Forking the child process sometimes fails under low memory condition.
      # It would be ideal for not forking the process to get RSS. For Linux,
      # this module reads '/proc/<pid>/status' to get RSS, but not for other
      # environments (e.g. MacOS and Windows).
      kb = `ps -o rss= -p #{Process.pid}`.to_i
      return kb * 1024
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
      RUBY_VERSION > "1.9" ? Random.rand(integer) : rand(integer)
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
