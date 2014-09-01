require 'spec_helper'

require 'tmpdir'
require 'fileutils'
require 'json'
require 'villein/event'

require 'mamiya/version'
require 'mamiya/agent'
require 'mamiya/agent/task_queue'
require 'mamiya/agent/actions'

require 'mamiya/configuration'

require_relative './support/dummy_serf.rb'

describe Mamiya::Agent do

  let(:serf) { DummySerf.new }

  let(:task_queue) do
    double('task_queue', start!: nil)
  end

  let(:config) do
    Mamiya::Configuration.new.evaluate! do
      set :serf, {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}}
    end
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
    allow(Mamiya::Agent::TaskQueue).to receive(:new).and_return(task_queue)
  end

  subject(:agent) { described_class.new(config) }

  it "includes actions" do
    expect(described_class.ancestors).to include(Mamiya::Agent::Actions)
  end

  describe "#trigger" do
    it "sends serf event" do
      expect(serf).to receive(:event).with(
        'mamiya:foo',
        {
          a: 'b',
          name: 'my-name',
        }.to_json,
        coalesce: true,
      )

      agent.trigger(:foo, a: 'b')
    end

    it "sends serf event with action" do
      expect(serf).to receive(:event).with(
        'mamiya:foo:bar',
        {
          a: 'b',
          name: 'my-name',
        }.to_json,
        coalesce: true,
      )

      agent.trigger(:foo, a: 'b', action: 'bar')
    end
  end

  describe "#run!" do
    it "starts serf, and task_queue" do
      begin
        flag = false

        expect(task_queue).to receive(:start!)
        expect(serf).to receive(:start!)
        expect(serf).to receive(:auto_stop) do
          flag = true
        end

        th = Thread.new { agent.run! }
        th.abort_on_exception = true

        10.times { break if flag; sleep 0.1 }
      ensure
        th.kill if th && th.alive?
      end
    end
  end

  describe "#status" do
    before do
      allow(agent).to receive(:existing_packages).and_return("app" => ["pkg"])

      allow(task_queue).to receive(:status).and_return({a: {working: nil, queue: []}})
    end

    subject(:status) { agent.status }

    it "doesn't include master=true" do
      expect(status[:master]).to be_nil
    end

    it "includes version identifier" do
      expect(status[:version]).to eq Mamiya::VERSION
    end

    it "includes agent name" do
      expect(status[:name]).to eq serf.name
    end

    it "includes packages" do
      expect(status[:packages]).to eq agent.existing_packages
    end

    context "with packages=false" do
      subject(:status) { agent.status(packages: false) }

      it "doesn't include existing packages" do
        expect(status.has_key?(:packages)).to be_false
      end
    end

    describe "(task queue)" do
      it "includes task_queue" do
        expect(status[:queues]).to eq({a: {working: nil, queue: []}})
      end
    end
  end

  describe "#existing_packages" do
    let!(:packages_dir) { Dir.mktmpdir('mamiya-agent-spec') }
    after { FileUtils.remove_entry_secure(packages_dir) }

    let(:config) { {packages_dir: packages_dir} }

    subject(:existing_packages) { agent.existing_packages }

    before do
      dir = Pathname.new(packages_dir)
      %w(a b).each do |app|
        dir.join(app).mkdir
        %w(valid.tar.gz valid.json
           valid-2.tar.gz valid-2.json
           invalid-1.tar.gz invalid-2.json invalid-3.txt).each do |name|
          File.write dir.join(app, name), "\n"
        end
      end
    end

    it "returns valid packages" do
      expect(existing_packages).to eq(
        "a" => ["valid", "valid-2"],
        "b" => ["valid", "valid-2"],
      )
    end
  end

  describe "query responder" do
    it "responds to 'mamiya:status'" do
      allow(agent).to receive(:status).with(packages: false).and_return("my" => "status")

      response = serf.trigger_query('mamiya:status', '')
      expect(JSON.parse(response)).to eq("my" => "status")
    end

    it "responds to 'mamiya:packages'" do
      allow(agent).to receive(:existing_packages).and_return(%w(pkg1 pkg2))

      response = serf.trigger_query('mamiya:packages', '')
      expect(JSON.parse(response)).to eq(%w(pkg1 pkg2))
    end
  end

  describe "event handler" do
    let(:handler_class) do
      Class.new(Mamiya::Agent::Handlers::Abstract) do
      end
    end

    def trigger(name, payload={})
      serf.trigger('user_event', Villein::Event.new(
        {
          'SERF_EVENT' => 'user',
          'SERF_USER_EVENT' => "mamiya:#{name}",
        },
        payload: payload.to_json,
      ))
    end

    before do
      stub_const("Mamiya::Agent::Handlers::Test", handler_class)
      agent # to create
    end

    it "finds handler class then call #run!" do
      expect_any_instance_of(handler_class).to receive(:run!)

      trigger('test')
    end

    it "passes proper argument to handler"

    context "when handler not found" do
      it "ignores event"
    end

    context "with events_only" do
      subject(:agent) { described_class.new(config, events_only: [/foo/]) }

      let(:handler_foo) do
        Class.new(Mamiya::Agent::Handlers::Abstract) do
        end
      end

      let(:handler_bar) do
        Class.new(Mamiya::Agent::Handlers::Abstract) do
          def run!
            raise 'oops?'
          end
        end
      end

      before do
        stub_const("Mamiya::Agent::Handlers::Foo", handler_foo)
        stub_const("Mamiya::Agent::Handlers::Bar", handler_bar)
      end

      it "handles events only matches any of them" do
        expect_any_instance_of(handler_foo).to receive(:run!)

        trigger('foo')
        trigger('bar')
      end
    end

    context "with action" do
      it "calls another method instead of run!" do
        expect_any_instance_of(handler_class).to receive(:hello)
        trigger('test:hello')
      end
    end
  end
end
