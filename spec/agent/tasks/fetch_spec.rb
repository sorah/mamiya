require 'spec_helper'

require 'mamiya/agent/tasks/fetch'
require 'mamiya/agent/tasks/notifyable'
require 'mamiya/steps/fetch'

describe Mamiya::Agent::Tasks::Fetch do
  let(:config) { {packages_dir: File::NULL} }
  let(:agent) { double('agent', config: config) }
  let(:task_queue) { double('task_queue', enqueue: nil) }

  let(:step) { double('step', run!: nil) }

  let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg'} }

  subject(:task) { described_class.new(task_queue, job, agent: agent, raise_error: true) }

  it 'inherits notifyable task' do
    expect(described_class.ancestors).to include(Mamiya::Agent::Tasks::Notifyable)
  end

  describe "#execute" do
    before do
      allow(Mamiya::Steps::Fetch).to receive(:new).with(
        application: 'myapp',
        package: 'mypkg',
        destination: File.join(File::NULL, 'myapp'),
        config: config,
      ).and_return(step)

      allow(agent).to receive(:trigger)
    end

    it "calls fetch step" do
      expect(step).to receive(:run!)

      task.execute
    end

    it "enqueues clean task" do
      expect(task_queue).to receive(:enqueue).with(:clean, {})

      task.execute
    end

    context "when already fetched" do
      it "does nothing" do
        allow(step).to receive(:run!).and_raise(Mamiya::Storages::Abstract::AlreadyFetched)

        expect {
          task.execute
        }.not_to raise_error
      end
    end
  end
end
