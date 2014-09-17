require 'spec_helper'
require 'mamiya/master/application_status'

describe Mamiya::Master::ApplicationStatus do
  let(:application) { 'myapp' }

  let(:agent_statuses) do
    {}
  end

  let(:agent_monitor) do
    double('agent_monitor', statuses: agent_statuses)
  end

  subject(:status) { described_class.new(agent_monitor, application) }

  describe "#participants" do
    subject { status.participants }

    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        },
        'agent2' => {
          'prereleases' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        },
        'agent3' => {
          'releases' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        },
        'agent4' => {
          'queues' => {'fetch' => {
            'working' => {'app' => 'myapp'},
            'queue' => [
            ]
          }}
        },
        'agent5' => {
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
              {'app' => 'myapp'},
            ]
          }}
        },
        'agent6' => {
          'currents' => {'myapp' => 'pkg'},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
              {'app' => 'notmyapp'},
            ]
          }}
        },
        'agent7' => {
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
              {'app' => 'notmyapp'},
            ]
          }}
        },
      }
    end

    it "returns participants" do
      expect(subject.keys.sort).to eq %w(agent1 agent2 agent3 agent4 agent5 agent6)
    end
  end

  describe "#currents" do
    subject { status.currents }

    let(:agent_statuses) do
      {
        'agent1' => {
          'currents' => {'myapp' => 'a'},
        },
        'agent2' => {
          'currents' => {'myapp' => 'b'},
        },
        'agent3' => {
          'currents' => {'myapp' => 'a'},
        },
      }
    end

    it { should eq('a' => %w(agent1 agent3), 'b' => %w(agent2)) }
  end

  describe "#major_current" do
    subject { status.major_current }

    let(:agent_statuses) do
      {
        'agent1' => {
          'currents' => {'myapp' => 'a'},
        },
        'agent2' => {
          'currents' => {'myapp' => 'b'},
        },
        'agent3' => {
          'currents' => {'myapp' => 'a'},
        },
      }
    end

    it { should eq 'a' }
  end

  describe "#common_releases" do
    subject { status.common_releases }

    let(:agent_statuses) do
      {
        'agent1' => {
          'releases' => {'myapp' => %w(a b c)},
        },
        'agent2' => {
          'releases' => {'myapp' => %w(b c d e)},
        },
        'agent3' => {
          'releases' => {'myapp' => %w(b c e)},
        },
      }
    end

    it { should eq %w(b c) }
  end

  describe "#common_previous_release" do
    subject { status.common_previous_release }

    let(:agent_statuses) do
      {
        'agent1' => {
          'currents' => {'myapp' => 'c'},
          'releases' => {'myapp' => %w(a b c)},
        },
        'agent2' => {
          'currents' => {'myapp' => 'c'},
          'releases' => {'myapp' => %w(b c d e)},
        },
        'agent3' => {
          'currents' => {'myapp' => 'b'},
          'releases' => {'myapp' => %w(b c e)},
        },
      }
    end

    it { should eq ?b }
  end
end
