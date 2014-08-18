require 'spec_helper'
require 'mamiya/agent/tasks/abstract'

describe Mamiya::Agent::Tasks::Abstract do
  let(:queue) { double('task_queue') }

  let(:job) { {} }
  subject(:task) { described_class.new(queue, job) }

  describe "#execute" do
    it "calls before, then run" do
      expect(task).to receive(:before).ordered
      expect(task).to receive(:run).ordered
      task.execute
    end
    it "calls after" do
      expect(task).to receive(:run).ordered
      expect(task).to receive(:after).ordered
      task.execute
    end
    it "handles error" do
      err = RuntimeError.new
      allow(task).to receive(:run).and_raise(err)
      task.execute
      expect(task.error).to eq err
    end
  end
end

