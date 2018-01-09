module Unicorn
  module WorkerKiller
    module MaxRequests
      include Randomize

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

      def process_client(client)
        super(client) # Unicorn::HttpServer#process_client

        return if @_worker_max_requests_min.zero? && @_worker_max_requests_max.zero?

        @_worker_process_start ||= Time.now
        @_worker_cur_requests  ||= @_worker_max_requests_min + randomize(@_worker_max_requests_max - @_worker_max_requests_min + 1)
        @_worker_max_requests  ||= @_worker_cur_requests

        logger.info "#{self}: worker (pid: #{Process.pid}) has #{@_worker_cur_requests} left before being killed" if @_verbose

        @_worker_cur_requests -= 1

        return if @_worker_cur_requests > 0

        logger.warn "#{self}: worker (pid: #{Process.pid}) exceeds max number of requests (limit: #{@_worker_max_requests})"

        Unicorn::WorkerKiller.kill_self(logger, @_worker_process_start)
      end
    end
  end
end
