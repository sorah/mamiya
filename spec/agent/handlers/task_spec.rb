require 'spec_helper'

require 'json'
require 'villein/event'

require 'mamiya/agent/handlers/task'

describe Mamiya::Agent::Handlers::Task do
  let(:event) do
    Villein::Event.new(
      {
        'SERF_EVENT' => 'user',
        'SERF_USER_EVENT' => 'mamiya:task',
      },
      payload: {
        task: 'fetch',
        application: 'app',
        package: 'package',
      }.to_json,
    )
  end

  let(:task_queue) { double('task_queue', enqueue: nil) }

  let(:agent) do
    double('agent', task_queue: task_queue)
  end

  subject(:handler) { described_class.new(agent, event) }

  before do
  end

  it "enqueue a request" do
    expect(task_queue).to receive(:enqueue).with(:fetch, 'task' => 'fetch', 'application' => 'app', 'package' => 'package')

    handler.run!
  end
end
