require 'spec_helper'
require 'mamiya/agent/tasks/notifyable'

describe Mamiya::Agent::Tasks::Notifyable do
  let(:queue) { double('task_queue') }
  let(:agent) { double('agent', trigger: nil) }

  # specifying 'task' key that Tasks::Abstract assigns,
  # to make expecting message easier
  let(:job) { {'foo' => 'bar', 'task' => 'notifyable'} }
  subject(:task) { described_class.new(queue, job, agent: agent) }

  describe "#execute" do
    it "notifies first, then :run" do
      expect(agent).to receive(:trigger).with('task', action: 'start', task: job).ordered
      expect(task).to receive(:before).ordered
      expect(task).to receive(:run).ordered
      task.execute
    end

    it "calls after, then notify" do
      expect(task).to receive(:run).ordered
      expect(task).to receive(:after).ordered
      expect(agent).to receive(:trigger).with('task', action: 'finish', task: job).ordered
      task.execute
    end

    it "handles error" do
      expect(agent).to receive(:trigger).with('task', action: 'error', task: job, error: RuntimeError.name)
      err = RuntimeError.new
      allow(task).to receive(:run).and_raise(err)
      task.execute
      expect(task.error).to eq err
    end
  end
end

