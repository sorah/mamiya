require 'spec_helper'

require 'mamiya/agent/tasks/abstract'
require 'mamiya/agent/tasks/ping'
require 'mamiya/configuration'

describe Mamiya::Agent::Tasks::Ping do
  let(:config) do
    Mamiya::Configuration.new
  end

  let(:agent) { double('agent', config: config) }
  let(:task_queue) { double('task_queue') }

  subject(:task) { described_class.new(task_queue, {}, agent: agent, raise_error: true) }

  it 'inherits abstract task' do
    expect(described_class.ancestors).to include(Mamiya::Agent::Tasks::Abstract)
  end

  describe "#execute" do
    let(:now) { Time.now }

    before do
      allow(Time).to receive(:now).and_return(now)
    end

    it "responds with it's task_id" do
      expect(agent).to receive(:trigger).with('pong', at: now.to_i, id: task.task_id, coalesce: false)

      task.execute
    end
  end
end
