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
    use Unicorn::WorkerKiller::MaxRequests, 3072, 4096
    
    # Max memory size (RSS) per worker
    use Unicorn::WorkerKiller::Oom, (192*(1024**2)), (256*(1024**2))

This gem provides two modules.

### Unicorn::WorkerKiller::MaxRequests(max_requests_min=3072, max_requests_max=4096)

This module automatically restarts the Unicorn workers, based on the number of requests which worker processed.

`max_requests_min` and `max_requests_max` specify the min and max of maximum requests per worker. The actual limit is decided by rand() between `max_requests_min` and `max_requests_max` per worker, to prevent all workers to be dead at the same time. Once the number exceeds the limit, that worker is automatically restarted.

### Unicorn::WorkerKiller::Oom(memory_limit_min=(1024**3), memory_limit_max=(2*(1024**3)), check_cycle = 16)

This module automatically restarts the Unicorn workers, based on its memory size.

`memory_limit_min` and `memory_limit_max` specify the min and max of maximum memory per worker. The actual limit is decided by rand() between `memory_limit_min` and `memory_limit_max` per worker, to prevent all workers to be dead at the same time.  Once the memory size exceeds `memory_size`, that worker is automatically restarted.

The memory size check is done in every `check_cycle` requests.

# Special Thanks

- [@hotchpotch](http://github.com/hotchpotch/) for the [original idea](https://gist.github.com/hotchpotch/1258681)

