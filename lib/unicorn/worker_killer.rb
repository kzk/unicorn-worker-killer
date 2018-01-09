require 'unicorn'
require 'get_process_mem'

require 'unicorn/worker_killer/configuration'
require 'unicorn/worker_killer/randomize'
require 'unicorn/worker_killer/middleware/max_requests'
require 'unicorn/worker_killer/middleware/oom'

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
    alive_sec  = (Time.now - start_time).round
    worker_pid = Process.pid

    @@kill_attempts ||= 0
    @@kill_attempts += 1

    sig = :QUIT
    sig = :TERM if @@kill_attempts > configuration.max_quit
    sig = :KILL if @@kill_attempts > configuration.max_term

    logger.warn "#{self} send SIG#{sig} (pid: #{worker_pid}) alive: #{alive_sec} sec (trial #{@@kill_attempts})"

    Process.kill(sig, worker_pid)
  end

  def self.configure
    self.configuration ||= Configuration.new

    yield(configuration) if block_given?
  end

  self.configure
end
