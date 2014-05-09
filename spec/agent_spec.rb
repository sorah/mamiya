require 'spec_helper'

require 'tmpdir'
require 'fileutils'
require 'json'
require 'villein/event'

require 'mamiya/agent'
require 'mamiya/agent/fetcher'
require 'mamiya/agent/actions'

require_relative './support/dummy_serf.rb'

describe Mamiya::Agent do

  let(:serf) { DummySerf.new }
  let(:fetcher) { double('fetcher', start!: nil, working?: false) }

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
