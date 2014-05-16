require 'spec_helper'
require 'json'

require 'mamiya/master/agent_monitor'

describe Mamiya::Master::AgentMonitor do
  let(:serf) { double('serf') }
  let(:master) do
    double('master', logger: Mamiya::Logger.new, serf: serf)
  end

  subject(:agent_monitor) do
    described_class.new(master)
  end

  describe "#commit_event" do
  end

  describe "#refresh" do
    let(:query_response) do
      {
        "Acks" => ['a'],
        "Responses" => {
          'a' => {"foo" => "bar"}.to_json,
        },
      }
    end

    let(:members) do
      [
        {
          "name"=>"a", "status"=>"alive",
          "addr"=>"x.x.x.x:7676", "port"=>7676,
          "protocol"=>{"max"=>4, "min"=>2, "version"=>4},
          "tags"=>{},
        },
      ]
    end

    before do
      allow(serf).to receive(:query).with('mamiya:status', '').and_return(query_response)
      allow(serf).to receive(:members).and_return(members)
    end

    it "updates #agents" do
      expect {
        agent_monitor.refresh
      }.to change {
        agent_monitor.agents
      }.from({}).to("a" => members[0])
    end

    context "when some member is failing" do
      let(:members) do
        [
          {
            "name"=>"a", "status"=>"failed",
            "addr"=>"x.x.x.x:7676", "port"=>7676,
            "protocol"=>{"max"=>4, "min"=>2, "version"=>4},
            "tags"=>{},
          },
        ]
      end

      it "appends to failed_agents" do
        expect {
          agent_monitor.refresh
        }.to change {
          agent_monitor.failed_agents
        }.from([]).to(['a'])
      end
    end

    context "when some agent returned invalid status" do
      let(:query_response) do
        {
          "Acks" => ['a'],
          "Responses" => {
            'a' => '{',
          },
        }
      end

      it "appends to failed_agents" do
        expect {
          agent_monitor.refresh
        }.to change {
          agent_monitor.failed_agents
        }.from([]).to(['a'])
      end
    end
  end
end
