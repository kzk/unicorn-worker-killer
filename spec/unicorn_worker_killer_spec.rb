require "get_process_mem"
require "net/http"
require "open3"
require "spec_helper"
require "unicorn_worker_killer"

describe UnicornWorkerKiller do
  context "when RAM-based reaping is enabled" do
    it "reaps workers based on RAM" do
      begin
        app_path = fixture_path.join("app.ru")
        stdin, stdout, stderr, thread = Open3.popen3(ENV, "UNICORN_WORKER_MEMORY=50 bundle exec unicorn #{app_path} -p 0")

        master_pid = thread.pid
        lines      = stderr.each_line.take(4)
        worker_pid = lines[-1].scan(/pid=[^ ]+/)[0].split("=")[1].chomp.to_i
        port       = lines[0].scan(/addr=[^ ]+/)[0].split(":")[1].chomp.to_i

        while GetProcessMem.new(worker_pid).bytes < 50 * 1024 * 1024
          Net::HTTP.get(URI.parse("http://0.0.0.0:#{port}"))
        end

        begin
          Timeout.timeout(1) do
            loop while %x{pgrep -P #{master_pid}}.chomp.to_i == worker_pid
          end
        rescue Timeout::Error
        ensure
          expect { Process.kill(:QUIT, worker_pid) }.to raise_error Errno::ESRCH
        end
      ensure
        stdin.close
        stdout.close
        stderr.close
        Process.kill("TERM", master_pid)
      end
    end

    it "only reaps as frequently as the memory_check_frequency setting" do
      begin
        app_path = fixture_path.join("app.ru")
        stdin, stdout, stderr, thread = Open3.popen3(ENV, "UNICORN_WORKER_MEMORY=1 UNICORN_WORKER_MEMORY_CHECK_FREQUENCY=10 bundle exec unicorn #{app_path} -p 0")

        master_pid = thread.pid
        lines      = stderr.each_line.take(4)
        worker_pid = lines[-1].scan(/pid=[^ ]+/)[0].split("=")[1].chomp.to_i
        port       = lines[0].scan(/addr=[^ ]+/)[0].split(":")[1].chomp.to_i

        9.times do
          Net::HTTP.get(URI.parse("http://0.0.0.0:#{port}"))
        end

        %x{pgrep -P #{master_pid}}.chomp.to_i.should eq worker_pid

        Net::HTTP.get(URI.parse("http://0.0.0.0:#{port}"))

        begin
          Timeout.timeout(1) do
            loop while %x{pgrep -P #{master_pid}}.chomp.to_i == worker_pid
          end
        rescue Timeout::Error
        ensure
          expect { Process.kill(:QUIT, worker_pid) }.to raise_error Errno::ESRCH
        end
      ensure
        stdin.close
        stdout.close
        stderr.close
        Process.kill("TERM", master_pid)
      end
    end
  end
end
