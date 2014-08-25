require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'villein/event'

require 'mamiya/agent'
require 'mamiya/storages/mock'

require 'mamiya/master/agent_monitor'
require 'mamiya/master'

require_relative './support/dummy_serf.rb'

describe Mamiya::Master do
  let(:serf) { DummySerf.new }
  let(:agent_monitor) { double('agent_monitor', start!: nil) }

  let(:config) do
    {
      serf: {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}},
      web: {port: 0, bind: 'localhost'},
      storage: {type: :mock},
    }
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
    allow(Mamiya::Master::AgentMonitor).to receive(:new).and_return(agent_monitor)
  end

  subject(:master) { described_class.new(config) }

  it "inherits Mamiya::Agent" do
    expect(described_class.superclass).to eq Mamiya::Agent
  end

  it "starts agent monitor"

  describe "(member join event)" do
    it "initiates refresh" do
      master # initiate

      expect(agent_monitor).to receive(:refresh).with(node: ['the-node', 'another-node'])

      serf.trigger("member_join", Villein::Event.new(
        {"SERF_EVENT" => "member-join"},
        payload: "the-node\tX.X.X.X\t\tkey=val,a=b\nanother-node\tY.Y.Y.Y\t\tkey=val,a=b\n"
      ))
    end
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
