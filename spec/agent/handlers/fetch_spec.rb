require 'spec_helper'

require 'json'
require 'villein/event'

require 'mamiya/agent/handlers/fetch'

describe Mamiya::Agent::Handlers::Fetch do
  let(:event) do
    Villein::Event.new(
      {
        'SERF_EVENT' => 'user',
        'SERF_USER_EVENT' => 'mamiya:fetch',
      },
      payload: {
        application: 'app',
        package: 'package',
      }.to_json,
    )
  end

  let(:fetcher) { double('fetcher', start!: nil) }
  let(:serf) { double('serf', name: 'myname', event: nil) }

  let(:agent) do
    double('agent', fetcher: fetcher, serf: serf, update_tags: nil)
  end

  subject(:handler) { described_class.new(agent, event) }

  before do
    allow(fetcher).to receive(:enqueue) do |&block|
      block.call
    end
  end

  it "enqueue a request" do
    expect(fetcher).to receive(:enqueue).with('app', 'package')

    handler.run!
  end

  it "responds ack" do
    allow(fetcher).to receive(:enqueue).with('app', 'package')
    expect(serf).to receive(:event).with('mamiya:fetch-result:ack',
      {name: serf.name, application: 'app', package: 'package'}.to_json)

    handler.run!
  end

  it "responds success" do
    callback = nil
    allow(fetcher).to receive(:enqueue).with('app', 'package') do |&block|
      callback = block
    end

    handler.run!

    expect(serf).to receive(:event).with(
      'mamiya:fetch-result:success',
      {name: serf.name, application: 'app', package: 'package'}.to_json
    )

    callback.call
  end

  it "updates tag" do
    expect(agent).to receive(:update_tags!)
    handler.run!
  end

  context "when failed" do
    it "notifies error" do
      callback = nil
      allow(fetcher).to receive(:enqueue).with('app', 'package') do |&block|
        callback = block
      end

      handler.run!

      error = RuntimeError.new('test')
      expect(serf).to receive(:event).with(
        'mamiya:fetch-result:error',
        {
          name: serf.name, application: 'app', package: 'package',
          error: error.inspect,
        }.to_json,
      )

      callback.call(error)
    end

    it "updates tag" do
      allow(fetcher).to receive(:enqueue) do |&block|
        block.call(Exception.new)
      end

      expect(agent).to receive(:update_tags)
      handler.run!
    end
  end
end
