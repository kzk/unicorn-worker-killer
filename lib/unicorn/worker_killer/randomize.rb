module Unicorn
  module WorkerKiller
    module Randomize
      def randomize(integer)
        RUBY_VERSION > '1.9' ? Random.rand(integer.abs) : rand(integer)
      end
    end
  end
end
