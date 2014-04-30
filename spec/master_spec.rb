require 'spec_helper'

require 'json'
require 'villein/event'

require 'mamiya/agent'

require 'mamiya/master'

require_relative './support/dummy_serf.rb'

describe Mamiya::Master do
  let(:serf) { DummySerf.new }

  let(:config) do
    {
      serf: {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}},
      web: {port: 0, bind: 'localhost'}
    }
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
  end

  subject(:master) { described_class.new(config) }

  it "inherits Mamiya::Agent" do
    expect(described_class.superclass).to eq Mamiya::Agent
  end

  describe "#run!" do
    it "starts serf and web" do
      begin
        flag = false

        expect_any_instance_of(Rack::Server).to receive(:start)
        expect(serf).to receive(:start!)
        expect(serf).to receive(:auto_stop) do
          flag = true
        end

        th = Thread.new { master.run! }
        th.abort_on_exception = true

        10.times { break if flag; sleep 0.1 }
      ensure
        th.kill if th && th.alive?
      end
    end
  end
end
