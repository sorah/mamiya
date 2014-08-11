require 'spec_helper'

require 'json'
require 'villein/event'

require 'mamiya/agent'
require 'mamiya/agent/actions'

require_relative '../support/dummy_serf.rb'

describe Mamiya::Agent::Actions do
  let(:serf) { DummySerf.new }
  let(:fetcher) { double('fetcher', start!: nil) }

  let(:config) do
    {serf: {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}}}
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
    allow(Mamiya::Agent::Fetcher).to receive(:new).and_return(fetcher)
  end

  subject(:agent) { Mamiya::Agent.new(config) }


  describe "#distribute" do
    it "sends fetch request" do
      expect(serf).to receive(:event).with(
        'mamiya:fetch',
        {application: 'app', package: 'pkg'}.to_json,
        coalesce: false
      )

      agent.distribute('app', 'pkg')
    end
  end
end
