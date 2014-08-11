require 'spec_helper'

require 'tmpdir'
require 'fileutils'
require 'json'
require 'villein/event'

require 'mamiya/version'
require 'mamiya/agent'
require 'mamiya/agent/fetcher'
require 'mamiya/agent/actions'

require_relative './support/dummy_serf.rb'

describe Mamiya::Agent do

  let(:serf) { DummySerf.new }
  let(:fetcher) do
    double('fetcher', start!: nil, working?: false).tap do |f|
      cleanup_hook = nil
      allow(f).to receive(:cleanup_hook=) { |_| cleanup_hook = _ }
      allow(f).to receive(:cleanup_hook)  { cleanup_hook }
    end
  end

  let(:config) do
    {serf: {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}}}
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
    allow(Mamiya::Agent::Fetcher).to receive(:new).and_return(fetcher)
  end

  subject(:agent) { described_class.new(config) }

  it "includes actions" do
    expect(described_class.ancestors).to include(Mamiya::Agent::Actions)
  end

  describe "fetcher" do
    it "sends events on cleanup hook" do
      expect(serf).to receive(:event).with(
        'mamiya:fetch-result:remove',
        {
          name: serf.name, application: 'foo', package: 'bar',
        }.to_json,
        coalesce: false,
      )

      agent.fetcher.cleanup_hook.call('foo', 'bar')
    end
  end

  describe "#run!" do
    it "starts serf and fetcher" do
      begin
        flag = false

        expect(fetcher).to receive(:start!)
        expect(serf).to receive(:start!)
        expect(serf).to receive(:auto_stop) do
          flag = true
        end

        th = Thread.new { agent.run! }

        10.times { break if flag; sleep 0.1 }
      ensure
        th.kill if th && th.alive?
      end
    end
  end

  describe "#update_tags!" do
    describe "(status)" do
      context "when it is not busy" do
        it "shows ready" do
          agent.update_tags!

          expect(serf.tags['mamiya']).to eq ',ready,'
        end
      end

      context "when it is fetching" do
        before do
          allow(fetcher).to receive(:working?).and_return(true)
        end

        it "shows fetching" do
          agent.update_tags!

          expect(serf.tags['mamiya']).to eq ',fetching,'
        end
      end

      context "when it is running multiple jobs" do
        pending
      end
    end

    describe "(prepared)" do
      pending
    end

    describe "(current)" do
      pending
    end
  end

  describe "#status" do
    before do
      allow(agent).to receive(:existing_packages).and_return("app" => ["pkg"])
      allow(fetcher).to receive(:queue_size).and_return(42)
      allow(fetcher).to receive(:working?).and_return(false)
      allow(fetcher).to receive(:current_job).and_return(nil)
      allow(fetcher).to receive(:pending_jobs).and_return([['app', 'pkg2', nil, nil]])
    end

    subject(:status) { agent.status }

    it "includes version identifier" do
      expect(status[:version]).to eq Mamiya::VERSION
    end

    it "includes agent name" do
      expect(status[:name]).to eq serf.name
    end

    it "includes packages" do
      expect(status[:packages]).to eq agent.existing_packages
    end

    describe "(fetcher)" do
      it "includes queue_size as pending" do
        expect(status[:fetcher][:pending]).to eq 42
      end

      it "includes pendings job" do
        expect(status[:fetcher][:pending_jobs]).to eq([['app', 'pkg2']])
      end

      it "shows fetching status" do
        expect(status[:fetcher][:fetching]).to be_nil
      end

      context "when it's fetching" do
        before do
          allow(fetcher).to receive(:working?).and_return(true)
          allow(fetcher).to receive(:current_job).and_return(%w(foo bar))
        end

        it "shows fetching true" do
          expect(status[:fetcher][:fetching]).to eq ['foo', 'bar']
        end
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
      allow(agent).to receive(:status).and_return("my" => "status")

      response = serf.trigger_query('mamiya:status', '')
      expect(JSON.parse(response)).to eq("my" => "status")
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
