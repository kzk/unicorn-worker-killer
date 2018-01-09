describe Unicorn::WorkerKiller::MaxRequests do
  let(:app) { double }
  let!(:http_server) { FakeHttpServer.new(app) }
  let(:mount_middleware) { described_class.new(app, 5, 10, true) }

  before { mount_middleware }

  describe 'initialization' do
    it { expect(mount_middleware).to eq(app) }
    it { expect(http_server.instance_variable_get(:@_worker_max_requests_min)).to eq(5) }
    it { expect(http_server.instance_variable_get(:@_worker_max_requests_max)).to eq(10) }
    it { expect(http_server.instance_variable_get(:@_verbose)).to be_truthy }
  end

  describe '#process_client' do
    subject { http_server.process_client(double) }

    it 'decreases requests counter' do
      http_server.instance_variable_set(:@_worker_cur_requests, 10)

      expect {
        subject
      }.to change { http_server.instance_variable_get(:@_worker_cur_requests) }.by(-1)
    end

    it 'sets process start timestamp' do
      Timecop.freeze

      expect {
        subject
      }.to change { http_server.instance_variable_get(:@_worker_process_start) }.to(Time.now)
    end

    context 'when requests counter reaches zero' do
      before { http_server.instance_variable_set(:@_worker_cur_requests, 1) }

      it 'performs suicide' do
        expect(Unicorn::WorkerKiller).to receive(:kill_self)

        subject
      end

      context 'when max requests min and max are zeros' do
        it 'does nothing' do
          http_server.instance_variable_set(:@_worker_max_requests_min, 0)
          http_server.instance_variable_set(:@_worker_max_requests_max, 0)

          expect(Unicorn::WorkerKiller).not_to receive(:kill_self)

          subject
        end
      end
    end
  end
end
