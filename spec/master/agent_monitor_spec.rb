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
      allow(serf).to receive(:query).with('mamiya:status', '', {}).and_return(query_response)
      allow(serf).to receive(:members).and_return(members)
    end

    it "updates #statuses" do
      expect {
        agent_monitor.refresh
      }.to change {
        agent_monitor.statuses["a"]
      }.to("foo" => "bar")
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

    context "with argument" do
      it "passes args to serf query" do
        expect(serf).to receive(:query).with('mamiya:status', '', node: 'foo').and_return(query_response)
        agent_monitor.refresh(node: 'foo')
      end
    end
  end

  describe "(commiting events)" do
    let(:query_response) do
      {
        "Acks" => ['a'],
        "Responses" => {
          'a' => status.to_json,
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
      allow(serf).to receive(:query).with('mamiya:status', '', {}).and_return(query_response)
      allow(serf).to receive(:members).and_return(members)

      agent_monitor.refresh
    end

    subject(:new_status) { agent_monitor.statuses["a"] }

    describe "task" do
      describe ":start" do
        context "if task is in the queue" do
          let(:status) do
            {task_queues: {
              a: {queue: [{task: 'a', foo: 'bar'}], working: nil}
            }}
          end

          it "removes from queue, set in working" do
            commit('mamiya:task:start',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['queue']).to be_empty
            expect(new_status['task_queues']['a']['working']).to eq('task' => 'a', 'foo' => 'bar')
          end
        end

        context "if task is not in the queue" do
          let(:status) do
            {task_queues: {
              a: {queue: [], working: nil}
            }}
          end

          it "set in working" do
            commit('mamiya:task:start',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to eq('task' => 'a', 'foo' => 'bar')
          end
        end
      end

      describe ":finish" do
        context "if task is working" do
          let(:status) do
            {task_queues: {
              a: {queue: [], working: {task: 'a', foo: 'bar'}}
            }}
          end

          it "removes from working" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to be_nil
          end
        end

        context "if task is in queue" do
          let(:status) do
            {task_queues: {
              a: {queue: [{task: 'a', foo: 'bar'}, {task: 'a', bar: 'baz'}], working: nil}
            }}
          end

          it "removes from queue" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to be_nil
            expect(new_status['task_queues']['a']['queue']).to eq [{'task' => 'a', 'bar' => 'baz'}]
          end
        end

        context "if task is not working" do
          let(:status) do
            {task_queues: {
              a: {queue: [], working: {task: 'a', foo: 'baz'}}
            }}
          end

          it "does nothing" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to eq('task' => 'a', 'foo' => 'baz')
            expect(new_status['task_queues']['a']['queue']).to eq []
          end
        end
      end

      describe ":error" do
        context "if task is working" do
          let(:status) do
            {task_queues: {
              a: {queue: [], working: {task: 'a', foo: 'bar'}}
            }}
          end

          it "removes from working" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to be_nil
          end
        end

        context "if task is in queue" do
          let(:status) do
            {task_queues: {
              a: {queue: [{task: 'a', foo: 'bar'}, {task: 'a', bar: 'baz'}], working: nil}
            }}
          end

          it "removes from queue" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to be_nil
            expect(new_status['task_queues']['a']['queue']).to eq [{'task' => 'a', 'bar' => 'baz'}]
          end
        end

        context "if task is not working" do
          let(:status) do
            {task_queues: {
              a: {queue: [], working: {task: 'a', foo: 'baz'}}
            }}
          end

          it "does nothing" do
            commit('mamiya:task:finish',
                   task: {task: 'a', foo: 'bar'})

            expect(new_status['task_queues']['a']['working']).to eq('task' => 'a', 'foo' => 'baz')
            expect(new_status['task_queues']['a']['queue']).to eq []
          end
        end
      end
    end

    describe "(task handling)" do
      describe "fetch" do
        describe "success" do
          let(:status) do
            {packages: {}}
          end

          it "updates packages" do
            commit('mamiya:task:finish',
                   task: {task: 'fetch', application: 'app', package: 'pkg'})

            expect(new_status["packages"]["app"]).to eq ["pkg"]
          end

          context "with existing packages" do
            let(:status) do
              {packages: {"app" => ['pkg1']}}
            end

            it "updates packages" do
              commit('mamiya:task:finish',
                     task: {task: 'fetch', application: 'app', package: 'pkg2'})

              expect(new_status["packages"]["app"]).to eq %w(pkg1 pkg2)
            end
          end
        end
      end
    end

    describe "fetch-result" do
      describe ":ack" do
        let(:status) do
          {fetcher: {fetching: nil, pending: 0}}
        end

        it "updates pending" do
          commit('mamiya:fetch-result:ack', pending: 72, application: 'foo', package: 'bar')
          expect(new_status["fetcher"]["pending"]).to eq 72
          expect(new_status["fetcher"]["pending_jobs"]).to eq [%w(foo bar)]
        end
      end

      describe ":start" do
        let(:status) do
          {fetcher: {fetching: nil, pending: 1, pending_jobs: [%w(app pkg)]}}
        end

        it "updates fetching" do
          commit('mamiya:fetch-result:start',
                 application: 'app', package: 'pkg', pending: 0)
          expect(new_status["fetcher"]["fetching"]).to eq ['app', 'pkg']
          expect(new_status["fetcher"]["pending_jobs"]).to be_empty
        end
      end

      describe ":error" do
        let(:status) do
          {fetcher: {fetching: ['app', 'pkg'], pending: 0}}
        end

        it "updates fetching" do
          commit('mamiya:fetch-result:error',
                 application: 'app', package: 'pkg', pending: 0)

          expect(new_status["fetcher"]["fetching"]).to eq nil
        end

        context "when package doesn't match with present state" do
          it "doesn't updates fetching" do
            commit('mamiya:fetch-result:error',
                   application: 'app', package: 'pkg2', pending: 0)

            expect(new_status["fetcher"]["fetching"]).to \
              eq(['app', 'pkg'])
          end
        end
      end

      describe ":success" do
        let(:status) do
          {fetcher: {fetching: ['app', 'pkg'], pending: 0},
           packages: {}}
        end

        it "updates fetching" do
          commit('mamiya:fetch-result:success',
                 application: 'app', package: 'pkg', pending: 0)

          expect(new_status["fetcher"]["fetching"]).to eq nil
        end

        it "updates packages" do
          commit('mamiya:fetch-result:success',
                 application: 'app', package: 'pkg', pending: 0)

          expect(new_status["packages"]["app"]).to eq ["pkg"]
        end

        context "with existing packages" do
          let(:status) do
            {fetcher: {fetching: ['app', 'pkg2'], pending: 0},
             packages: {"app" => ['pkg1']}}
          end

          it "updates packages" do
            commit('mamiya:fetch-result:success',
                   application: 'app', package: 'pkg2', pending: 0)

            expect(new_status["packages"]["app"]).to eq %w(pkg1 pkg2)
          end
        end

        context "when package doesn't match with present state" do
          it "doesn't updates fetching" do
            commit('mamiya:fetch-result:success',
                   application: 'app', package: 'pkg2', pending: 0)

            expect(agent_monitor.statuses["a"]["fetcher"]["fetching"]).to \
              eq(['app', 'pkg'])
          end

          it "updates packages" do
            commit('mamiya:fetch-result:success',
                   application: 'app', package: 'pkg', pending: 0)

            expect(new_status["packages"]["app"]).to eq ["pkg"]
          end
        end
      end

      describe ":remove" do
        context "with existing packages" do
          let(:status) do
            {fetcher: {fetching: ['app', 'pkg2'], pending: 0},
             packages: {"app" => ['pkg1']}}
          end

          it "updates packages" do
            commit('mamiya:fetch-result:remove',
                   application: 'app', package: 'pkg1', pending: 0)

            expect(new_status["packages"]["app"]).to eq []
          end
        end
      end
    end
  end
end
