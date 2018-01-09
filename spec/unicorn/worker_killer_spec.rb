describe Unicorn::WorkerKiller do
  let(:logger) { double(warn: nil) }

  describe '.kill_self' do
    subject { described_class.kill_self(logger, Time.now) }

    it 'increases kill attempts' do
      allow(Process).to receive(:kill)
      described_class.class_variable_set(:@@kill_attempts, 0)

      expect {
        subject
      }.to change { described_class.class_variable_get(:@@kill_attempts) }.by(1)
    end

    it 'tries to quit current process' do
      expect(Process).to receive(:kill).with(:QUIT, Process.pid)

      subject
    end

    context 'when max quit attempts exceeded' do
      before { described_class.class_variable_set(:@@kill_attempts, 10) }

      it 'tries to terminate current process' do
        expect(Process).to receive(:kill).with(:TERM, Process.pid)

        subject
      end
    end

    context 'when max term attempts exceeded' do
      before { described_class.class_variable_set(:@@kill_attempts, 15) }

      it 'tries to kill current process' do
        expect(Process).to receive(:kill).with(:KILL, Process.pid)

        subject
      end
    end
  end
end
