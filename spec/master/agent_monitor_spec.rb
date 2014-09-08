require 'spec_helper'
require 'json'

require 'villein/event'

require 'mamiya/master/agent_monitor'

describe Mamiya::Master::AgentMonitor do
  let(:serf) { double('serf') }
  let(:config) { {} }
  let(:master) do
    double('master', logger: Mamiya::Logger.new, serf: serf, config: config)
  end

  subject(:agent_monitor) do
    described_class.new(master)
  end

  def stub_serf_queries(expected_payload: '', expected_kwargs: {})
    allow(serf).to receive(:query) do |query, payload, kwargs={}|
      expect(payload).to eq expected_payload
      expect(kwargs).to eq expected_kwargs
      expect(%w(mamiya:status mamiya:packages)).to include(query)

      {'mamiya:status' => status_query_response, 'mamiya:packages' => packages_query_response}[query]
    end
  end

  let(:status_query_response) do
    {
      "Acks" => ['a'],
      "Responses" => {
        'a' => {"foo" => "bar", 'packages' => {"app" => ['pkg1']}}.to_json,
      },
    }
  end

  let(:packages_query_response) do
    {
      "Acks" => ['a'],
      "Responses" => {
        'a' => {"app" => ['pkg1','pkg2']}.to_json,
      },
    }
  end

  describe "#refresh" do
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
      stub_serf_queries()
      allow(serf).to receive(:members).and_return(members)
    end

    it "updates #statuses" do
      expect {
        agent_monitor.refresh
      }.to change {
        agent_monitor.statuses["a"] && agent_monitor.statuses["a"]['foo']
      }.to('bar')
    end

    it "updates #last_refresh_at" do
      agent_monitor.refresh
      expect(agent_monitor.last_refresh_at).to be_a_kind_of(Time)

      expect {
        agent_monitor.refresh
      }.to change {
        agent_monitor.last_refresh_at
      }
    end


    it "updates status .packages by packages query" do
      expect {
        agent_monitor.refresh
      }.to change {
        agent_monitor.statuses["a"] && agent_monitor.statuses["a"]['packages']
      }.to("app" => %w(pkg1 pkg2))
    end

    context "when packages query unavailable, but available in status query" do
      let(:packages_query_response) do
        {
          "Acks" => ['a'],
          "Responses" => {
          },
        }
      end

      it "updates status .packages from status" do
        expect {
          agent_monitor.refresh
        }.to change {
          agent_monitor.statuses["a"] && agent_monitor.statuses["a"]['packages']
        }.to("app" => %w(pkg1))
      end
    end

    context "when failed to retrieve package list, but it was available previously in packages query" do
      before do
        agent_monitor.refresh
        packages_query_response['Responses'] = {}
      end

      it "keeps previous list" do
        expect {
          agent_monitor.refresh
        }.not_to change {
          agent_monitor.statuses["a"]['packages']
        }
      end
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
      let(:status_query_response) do
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

    context "with argument" do
      it "passes args to serf query", pending: 'stub_serf_queries cannot handle kwarg' do
        stub_serf_queries(expected_kwargs: {node: 'foo'})
        agent_monitor.refresh(node: 'foo')
      end
    end
  end

  describe "(commiting events)" do
    let(:status_query_response) do
      {
        "Acks" => ['a'],
        "Responses" => {
          'a' => status.to_json,
        },
      }
    end

    let(:packages_query_response) do
      {
        "Acks" => ['a'],
        "Responses" => {
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

    let(:status) do
      {}
    end

    def commit(event, payload)
      agent_monitor.commit_event(Villein::Event.new(
        {
          'SERF_EVENT' => 'user',
          'SERF_USER_EVENT' => event,
        },
        payload: {name: "a"}.merge(payload).to_json
      ))
    end

    before do
      stub_serf_queries()
      allow(serf).to receive(:members).and_return(members)

      agent_monitor.refresh
    end

    subject(:new_status) { agent_monitor.statuses["a"] }

    describe "task" do
      describe ":start" do
        context "if task is in the queue" do
          let(:status) do
            {queues: {
              a: {queue: [{task: 'a', foo: 'bar'}], working: nil}
            }}
          end

          it "removes from queue, set in working" do
            commit('mamiya:task:start',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['queue']).to be_empty
            expect(new_status['queues']['a']['working']).to eq('task' => 'a', 'foo' => 'bar')
          end
        end

        context "if task is not in the queue" do
          let(:status) do
            {queues: {
              a: {queue: [], working: nil}
            }}
          end

          it "set in working" do
            commit('mamiya:task:start',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to eq('task' => 'a', 'foo' => 'bar')
          end
        end
      end

      describe ":finish" do
        context "if task is working" do
          let(:status) do
            {queues: {
              a: {queue: [], working: {task: 'a', foo: 'bar'}}
            }}
          end

          it "removes from working" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to be_nil
          end
        end

        context "if task is in queue" do
          let(:status) do
            {queues: {
              a: {queue: [{task: 'a', foo: 'bar'}, {task: 'a', bar: 'baz'}], working: nil}
            }}
          end

          it "removes from queue" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to be_nil
            expect(new_status['queues']['a']['queue']).to eq [{'task' => 'a', 'bar' => 'baz'}]
          end
        end

        context "if task is not working" do
          let(:status) do
            {queues: {
              a: {queue: [], working: {task: 'a', foo: 'baz'}}
            }}
          end

          it "does nothing" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to eq('task' => 'a', 'foo' => 'baz')
            expect(new_status['queues']['a']['queue']).to eq []
          end
        end
      end

      describe ":error" do
        context "if task is working" do
          let(:status) do
            {queues: {
              a: {queue: [], working: {task: 'a', foo: 'bar'}}
            }}
          end

          it "removes from working" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to be_nil
          end
        end

        context "if task is in queue" do
          let(:status) do
            {queues: {
              a: {queue: [{task: 'a', foo: 'bar'}, {task: 'a', bar: 'baz'}], working: nil}
            }}
          end

          it "removes from queue" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to be_nil
            expect(new_status['queues']['a']['queue']).to eq [{'task' => 'a', 'bar' => 'baz'}]
          end
        end

        context "if task is not working" do
          let(:status) do
            {queues: {
              a: {queue: [], working: {task: 'a', foo: 'baz'}}
            }}
          end

          it "does nothing" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['queues']['a']['working']).to eq('task' => 'a', 'foo' => 'baz')
            expect(new_status['queues']['a']['queue']).to eq []
          end
        end
      end
    end

    describe "(task handling)" do
      describe "pkg" do
        describe ":remove" do
          let(:status) do
            {packages: {'myapp' => ['pkg1']}}
          end

          it "removes removed package from packages" do
            commit('mamiya:pkg:remove',
                   application: 'myapp', package: 'pkg1')

            expect(new_status["packages"]['myapp']).to eq []
          end

          context "with existing packages" do
            let(:status) do
              {packages: {'myapp' => ['pkg1', 'pkg2']}}
            end

            it "removes removed package from packages" do
              commit('mamiya:pkg:remove',
                     application: 'myapp', package: 'pkg1')

              expect(new_status["packages"]['myapp']).to eq ['pkg2']
            end
          end

          context "with inexist package" do
            let(:status) do
              {packages: {'myapp' => ['pkg1', 'pkg3']}}
            end

            it "removes removed package from packages" do
              commit('mamiya:pkg:remove',
                     application: 'myapp', package: 'pkg2')

              expect(new_status["packages"]['myapp']).to eq ['pkg1', 'pkg3']
            end
          end
        end
      end

      describe "fetch" do
        describe "success" do
          let(:status) do
            {packages: {}}
          end

          it "updates packages" do
            commit('mamiya:task:finish',
                   task: {task: 'fetch', app: 'myapp', pkg: 'pkg'})

            expect(new_status["packages"]['myapp']).to eq ["pkg"]
          end

          context "with existing packages" do
            let(:status) do
              {packages: {'myapp' => ['pkg1']}}
            end

            it "updates packages" do
              commit('mamiya:task:finish',
                     task: {task: 'fetch', app: 'myapp', pkg: 'pkg2'})

              expect(new_status["packages"]['myapp']).to eq %w(pkg1 pkg2)
            end
          end
        end
      end
    end
  end
end
