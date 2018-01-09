describe Unicorn::WorkerKiller::Oom do
  let(:app) { double }
  let!(:http_server) { FakeHttpServer.new(app) }
  let(:mount_middleware) { described_class.new(app, 1, 2, 3, true) }

  before { mount_middleware }

  describe 'initialization' do
    it { expect(mount_middleware).to eq(app) }
    it { expect(http_server.instance_variable_get(:@_worker_memory_limit_min)).to eq(1) }
    it { expect(http_server.instance_variable_get(:@_worker_memory_limit_max)).to eq(2) }
    it { expect(http_server.instance_variable_get(:@_worker_check_cycle)).to eq(3) }
    it { expect(http_server.instance_variable_get(:@_worker_check_count)).to eq(0) }
    it { expect(http_server.instance_variable_get(:@_verbose)).to be_truthy }
  end

  describe '#process_client' do
    subject { http_server.process_client(double) }

    it 'increases check counter' do
      expect {
        subject
      }.to change { http_server.instance_variable_get(:@_worker_check_count) }.by(1)
    end

    it 'sets process start timestamp' do
      Timecop.freeze

      expect {
        subject
      }.to change { http_server.instance_variable_get(:@_worker_process_start) }.to(Time.now)
    end

    context 'when check and kill cycle reached' do
      before { http_server.instance_variable_set(:@_worker_check_count, 2) }

      it 'resets check counter' do
        allow_any_instance_of(GetProcessMem).to receive_messages(bytes: 0)

        expect {
          subject
        }.to change { http_server.instance_variable_get(:@_worker_check_count) }.from(2).to(0)
      end

      context 'when current memory usage is greater than allowed' do
        it 'performs suicide' do
          http_server.instance_variable_set(:@_worker_memory_limit, 100)
          allow_any_instance_of(GetProcessMem).to receive_messages(bytes: 101)

          expect(Unicorn::WorkerKiller).to receive(:kill_self)

          subject
        end
      end
    end
  end
end
