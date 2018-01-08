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

    it 'increases @_worker_check_count' do
      expect {
        subject
      }.to change { http_server.instance_variable_get(:@_worker_check_count) }.by(1)
    end

    it 'sets @_worker_process_start' do
      Timecop.freeze

      expect {
        subject
      }.to change { http_server.instance_variable_get(:@_worker_process_start) }.to(Time.now)
    end
  end
end
