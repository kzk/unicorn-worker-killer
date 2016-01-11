module Unicorn::WorkerKiller
  class Configuration
    attr_accessor :max_quit, :max_term, :sleep_interval, :callback

    def initialize
      self.max_quit = 10
      self.max_term = 15
      self.sleep_interval = 1
      self.callback = -> {}
    end

    def before_kill(&block)
      self.callback = block
    end
  end
end
