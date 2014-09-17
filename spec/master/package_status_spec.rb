require 'spec_helper'
require 'mamiya/master/package_status'

describe Mamiya::Master::PackageStatus do
  let(:application) { 'myapp' }
  let(:package) { 'mypackage' }

  let(:agent_statuses) do
    {}
  end

  let(:agent_monitor) do
    double('agent_monitor', statuses: agent_statuses)
  end

  subject(:status) { described_class.new(agent_monitor, application, package) }

  # TODO: FIXME: Add test to confirm ignoring master node

  describe "#status" do
    subject { status.status }

    context "if there's fetching agents" do
      let(:agent_statuses) do
        {
          'agent1' => {
            'packages' => {'myapp' => [
            ]},
            'queues' => {'fetch' => {
              'working' => {
                'task' => 'fetch',
                'app' => 'myapp',
                'pkg' => 'mypackage'
              },
              'queue' => [
              ]
            }}
          },
          'agent2' => {
            'packages' => {'myapp' => [
              'mypackage',
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }}
          }
        }
      end

      it { should include(:distributing) }
      it { should include(:partially_distributed) }
    end

    context "if there's queued agents" do
      let(:agent_statuses) do
        {
          'agent1' => {
            'packages' => {'myapp' => [
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
                {
                  'task' => 'fetch',
                  'app' => 'myapp',
                  'pkg' => 'mypackage'
                }
              ]
            }}
          },
          'agent2' => {
            'packages' => {'myapp' => [
              'mypackage',
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }}
          }
        }
      end

      it { should include(:distributing) }
      it { should include(:partially_distributed) }
    end

    context "if any agents have the package" do
      let(:agent_statuses) do
        {
          'agent1' => {
            'packages' => {'myapp' => [
              'mypackage',
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }},
          },
          'agent2' => {
            'packages' => {'myapp' => [
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }}
          }
        }
      end

      it { should include(:partially_distributed) }
    end

    context "if all agents have the package" do
      let(:agent_statuses) do
        {
          'agent1' => {
            'packages' => {'myapp' => [
              'mypackage',
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }},
          },
          'agent2' => {
            'packages' => {'myapp' => [
              'mypackage',
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }}
          }
        }
      end

      it { should include(:distributed) }
    end

    context "if no agents relate to the package" do
      let(:agent_statuses) do
        {
          'agent1' => {
            'packages' => {'myapp' => [
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }},
          },
          'agent2' => {
            'packages' => {'myapp' => [
            ]},
            'queues' => {'fetch' => {
              'working' => nil,
              'queue' => [
              ]
            }}
          }
        }
      end

      it { should eq [:unknown] }
    end
  end

  describe "#fetch_queued_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => {
                'task' => 'fetch',
                'app' => 'myapp',
                'pkg' => 'anotherpackage',
            },
            'queue' => [
              {
                'task' => 'fetch',
                'app' => 'myapp',
                'pkg' => 'mypackage',
              }
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns queued agents" do
      expect(status.fetch_queued_agents).to eq %w(agent1)
    end
  end

  describe "#fetching_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => {
              'task' => 'fetch',
              'app' => 'myapp',
              'pkg' => 'mypackage',
            },
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns fetching agents" do
      expect(status.fetching_agents).to eq %w(agent1)
    end
  end

  describe "#fetched_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => {
              'task' => 'fetch',
              'app' => 'myapp',
              'pkg' => 'mypackage',
            },
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns fetched agents" do
      expect(status.fetched_agents).to eq %w(agent2)
    end
  end

  ###

  describe "#prepare_queued_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'prepare' => {
            'working' => {
                'task' => 'prepare',
                'app' => 'myapp',
                'pkg' => 'anotherpackage',
            },
            'queue' => [
              {
                'task' => 'prepare',
                'app' => 'myapp',
                'pkg' => 'mypackage',
              }
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'prepare' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns queued agents" do
      expect(status.prepare_queued_agents).to eq %w(agent1)
    end
  end

  describe "#preparing_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'prepare' => {
            'working' => {
              'task' => 'prepare',
              'app' => 'myapp',
              'pkg' => 'mypackage',
            },
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'prepare' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns preparing agents" do
      expect(status.preparing_agents).to eq %w(agent1)
    end
  end

  describe "#prepared_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'prepare' => {
            'working' => {
              'task' => 'prepare',
              'app' => 'myapp',
              'pkg' => 'mypackage',
            },
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'prepare' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns prepared agents" do
      expect(status.prepared_agents).to eq %w(agent2)
    end
  end

  ###
 
  describe "#switch_queued_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'switch' => {
            'working' => {
                'task' => 'switch',
                'app' => 'myapp',
                'pkg' => 'anotherpackage',
            },
            'queue' => [
              {
                'task' => 'switch',
                'app' => 'myapp',
                'pkg' => 'mypackage',
              }
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'switch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns queued agents" do
      expect(status.switch_queued_agents).to eq %w(agent1)
    end
  end

  describe "#switching_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'switch' => {
            'working' => {
              'task' => 'switch',
              'app' => 'myapp',
              'pkg' => 'mypackage',
            },
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'switch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns switching agents" do
      expect(status.switching_agents).to eq %w(agent1)
    end
  end

  describe "#current_agents" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'currents' => {'myapp' => 'prevpkg'},
          'queues' => {'switch' => {
            'working' => {
              'task' => 'switch',
              'app' => 'myapp',
              'pkg' => 'mypackage',
            },
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'prereleases' => {'myapp' => [
            'mypackage'
          ]},
          'currents' => {'myapp' => 'mypackage'},
          'queues' => {'switch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns current agents" do
      expect(status.current_agents).to eq %w(agent2)
    end
  end

  ###

  describe "#non_participants" do
    let(:agent_statuses) do
      {
        'agent1' => {
          'packages' => {'myapp' => [
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }},
        },
        'agent2' => {
          'packages' => {'myapp' => [
            'mypackage'
          ]},
          'queues' => {'fetch' => {
            'working' => nil,
            'queue' => [
            ]
          }}
        }
      }
    end

    it "returns non participants" do
      expect(status.non_participants).to eq %w(agent1)
    end
  end
end
