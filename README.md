# unicorn-worker-killer

Killing Unicorn worker based on 1) Max number of requests and 2) Process memory size (RSS), without affecting the request.

# Install

    gem 'unicorn-worker-killer'

# Usage

add these lines to your config.ru.

    # Unicorn self-process killer
    require 'unicorn/worker_killer'
    
    # Max requests per worker
    use UnicornWorkerKiller::MaxRequests, 10240 + Random.rand(10240)
    
    # Max memory size (RSS) per worker
    use UnicornWorkerKiller::Oom, (96 + Random.rand(32)) * 1024**2

# TODO
- Get RSS (Resident Set Size) without forking the child process at Mac OS and Windows
