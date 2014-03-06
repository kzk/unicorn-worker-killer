module UnicornWorkerKiller
  module ProcessClient
    def process_client(client)
      super

      if respond_to?(:unicorn_worker_killer_reap_on_memory)
        unicorn_worker_killer_reap_on_memory
      end
    end
  end
end
