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

  describe ".identifier" do
    it "returns class name without module name" do
      allow(described_class).to receive(:name).and_return('Mamiya::Agent::Tasks::Foo')
      expect(described_class.identifier).to eq 'foo'
    end

    it "returns camelcased class name" do
      allow(described_class).to receive(:name).and_return('Mamiya::Agent::Tasks::FooBar')
      expect(described_class.identifier).to eq 'foo_bar'
    end
  end
end

