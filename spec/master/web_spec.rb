require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'mamiya/storages/mock'
require 'mamiya/package'

require 'mamiya/master/web'

describe Mamiya::Master::Web do
  include Rack::Test::Methods

  let!(:tmpdir) { Dir.mktmpdir('maimya-master-web-spec') }
  after { FileUtils.remove_entry_secure(tmpdir) }

  let(:app) { described_class }

  let(:config_source) do
    {}
  end

  let(:config) do
    double('config').tap do |c|
      allow(c).to receive(:[]) do |k|
        config_source[k]
      end
    end
  end

  let(:agent_statuses) do
    {}
  end

  let(:agent_monitor) do
    double('agent_monitor', statuses: agent_statuses)
  end

  let(:master) do
    double('master', config: config, agent_monitor: agent_monitor).tap do |m|
      allow(m).to receive(:storage) do |app|
        Mamiya::Storages::Mock.new(application: app)
      end
    end
  end

  let(:package) do
    File.write File.join(tmpdir, 'mypackage.tar.gz'), "\n"
    File.write File.join(tmpdir, 'mypackage.json'), "#{{meta: 'data'}.to_json}\n"
    Mamiya::Package.new(File.join(tmpdir, 'mypackage'))
  end

  before do
    described_class.set :environment, :test

    current_session.envs["rack.logger"] = Mamiya::Logger.new
    current_session.envs["mamiya.master"] = master

    Mamiya::Storages::Mock.new(application: 'myapp').push(package)
  end

  describe "GET /" do
    it "returns text" do
      get '/'

      expect(last_response.status).to eq 200
      expect(last_response.body).to match(/^mamiya/)
    end
  end

  describe "GET /packages/:application" do
    it "returns package list" do
      get '/packages/myapp'

      expect(last_response.status).to eq 200
      expect(last_response.content_type).to eq 'application/json'
      json = JSON.parse(last_response.body)
      expect(json['packages']).to eq ['mypackage']
    end

    it "returns empty list with 204 for inexistence app" do
      get '/packages/noapp'

      expect(last_response.status).to eq 404
      expect(last_response.content_type).to eq 'application/json'
      json = JSON.parse(last_response.body)
      expect(json['packages']).to eq []
    end
  end

  describe "GET /packages/:application/:package" do
    it "returns package detail" do
      get '/packages/myapp/mypackage'

      expect(last_response.status).to eq 200
      expect(last_response.content_type).to eq 'application/json'
      json = JSON.parse(last_response.body)
      expect(json['application']).to eq 'myapp'
      expect(json['name']).to eq 'mypackage'
      expect(json['meta']).to eq('meta' => 'data')
    end

    context "when not exists" do
      it "returns 404" do
        get '/packages/myapp/mypkg'

        expect(last_response.status).to eq 404
        expect(last_response.content_type).to eq 'application/json'
        expect(JSON.parse(last_response.body)).to eq({})
      end
    end
  end

  describe "POST /packages/:application/:package/distribute" do
    it "dispatchs distribute request" do
      expect(master).to receive(:distribute).with('myapp', 'mypackage')

      post '/packages/myapp/mypackage/distribute'

      expect(last_response.status).to eq 204 # no content
    end

    context "when package not found" do
      it "returns 404" do
        post '/packages/myapp/noexist/distribute'
        expect(last_response.status).to eq 404
      end
    end
  end

  describe "GET /package/:application/:package/distribution" do
    subject(:distribution) do
      res = get('/packages/myapp/mypackage/distribution')
      expect(res.status).to eq 200
      JSON.parse res.body
    end

    context "when package exists" do
      describe "about status" do
        subject { distribution['status'] }

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

          it { should eq 'distributing' }
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

          it { should eq 'distributing' }
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

          it { should eq 'partially_distributed' }
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

          it { should eq 'distributed' }
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

          it { should eq 'unknown' }
        end
      end

      describe "about fetching agents" do
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

        it "show in fetching" do
          expect(distribution['fetching']).to eq %w(agent1)
          expect(distribution['fetching_count']).to eq 1
        end
      end

      describe "about distribued agents" do
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

        it "show in distributed" do
          expect(distribution['distributed']).to eq %w(agent2)
          expect(distribution['distributed_count']).to eq 1
        end
      end

      describe "about queued agents" do
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

        it "show in queued" do
          expect(distribution['queued']).to eq %w(agent1)
          expect(distribution['queued_count']).to eq 1
        end
      end

      describe "about unknown agents" do
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

        it "show in not_distributed" do
          expect(distribution['not_distributed']).to eq %w(agent1)
          expect(distribution['not_distributed_count']).to eq 1
        end
      end

      context "with count_only" do
        subject(:distribution) do
          res = get('/packages/myapp/mypackage/distribution?count_only=1')
          expect(res.status).to eq 200
          JSON.parse res.body
        end

        it "returns only count columns" do
          expect(distribution.keys).not_to include('distributed')
          expect(distribution.keys).not_to include('fetching')
          expect(distribution.keys).not_to include('queued')
          expect(distribution.keys).not_to include('not_distributed')

          expect(distribution.keys).to include('distributed_count')
          expect(distribution.keys).to include('fetching_count')
          expect(distribution.keys).to include('queued_count')
          expect(distribution.keys).to include('not_distributed_count')
        end
      end
    end

    context "when package not found" do
      it "returns 404" do
        get '/packages/myapp/noexist/distribution'
        expect(last_response.status).to eq 404
      end
    end
  end
end
