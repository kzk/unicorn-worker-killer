# unicorn-worker-killer

[Unicorn](http://unicorn.bogomips.org/) is widely used HTTP-server for Rack applications. One thing we thought Unicorn misssed, is killing the Unicorn workers based on the number of requests and consumed memories.

`unicorn-worker-killer` gem provides automatic restart of Unicorn workers based on 1) max number of requests, and 2) process memory size (RSS), without affecting any requests. This will greatly improves site's stability by avoiding unexpected memory exhaustion at the application nodes.

# Install

No external process like `god` is required. Just install one gem: `unicorn-worker-killer`.

    gem 'unicorn-worker-killer'

# Usage

Add these lines to your `config.ru`.

    # Unicorn self-process killer
    require 'unicorn/worker_killer'
    
    # Max requests per worker
    use Unicorn::WorkerKiller::MaxRequests, 10240 + Random.rand(10240)
    
    # Max memory size (RSS) per worker
    use Unicorn::WorkerKiller::Oom, (96 + Random.rand(32)) * 1024**2

This gem provides two modules.

### Unicorn::WorkerKiller::MaxRequests(max_requests = 1024)

This module automatically restarts the Unicorn workers, based on the number of requests which worker processed.

`max_requests` specifies the maximum number of requests which this worker should process. Once the number exceeds `max_requests`, that worker is automatically restarted. It's highly recommended to randomize this number to avoid restarting all workers at once.

### Unicorn::WorkerKiller::Oom(memory_size = (1024**3), check_cycle = 16)

This module automatically restarts the Unicorn workers, based on its memory size.

`memory_size` specifies the maximum memory which this worker can have. Once the memory size exceeds `memory_size`, that worker is automatically restarted. It's highly recommended to randomize this number to avoid restarting all workers at once.

The memory size check is done in every `check_cycle` requests.

# TODO
- Get RSS (Resident Set Size) without forking the child process at Mac OS and Windows
