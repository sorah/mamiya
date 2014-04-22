require 'spec_helper'

require 'json'
require 'villein/event'

require 'mamiya/agent'
require 'mamiya/agent/fetcher'

require_relative './support/dummy_serf.rb'

describe Mamiya::Agent do
  let(:serf) { DummySerf.new }
  let(:fetcher) { double('fetcher', start!: nil) }

  let(:config) do
    {serf: {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}}}
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
    allow(Mamiya::Agent::Fetcher).to receive(:new).and_return(fetcher)
  end

  subject(:agent) { described_class.new(config) }

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

  describe "events:" do
    describe "fetch" do
      def trigger_fetch_request
        serf.trigger('user_event', Villein::Event.new(
          {
            'SERF_EVENT' => 'user',
            'SERF_USER_EVENT' => 'mamiya-fetch',
          },
          payload: {
            application: 'app',
            package: 'package',
          }.to_json,
        ))
      end

      before do
        allow(fetcher).to receive(:enqueue) do |&block|
          block.call
        end

        agent # to create
      end

      it "enqueue a request" do
        expect(fetcher).to receive(:enqueue).with('app', 'package')

        trigger_fetch_request
      end

      it "responds ack" do
        allow(fetcher).to receive(:enqueue).with('app', 'package')
        expect(serf).to receive(:event).with('mamiya-fetch-ack',
          {name: serf.name, application: 'app', package: 'package'}.to_json)

        trigger_fetch_request
      end

      it "responds success" do
        callback = nil
        allow(fetcher).to receive(:enqueue).with('app', 'package') do |&block|
          callback = block
        end

        trigger_fetch_request

        expect(serf).to receive(:event).with(
          'mamiya-fetch-success',
          {name: serf.name, application: 'app', package: 'package'}.to_json
        )

        callback.call
      end

      it "updates tag" do
        expect(agent).to receive(:update_tags)
        trigger_fetch_request
      end

      context "when failed" do
        it "notifies error" do
          callback = nil
          allow(fetcher).to receive(:enqueue).with('app', 'package') do |&block|
            callback = block
          end

          trigger_fetch_request

          error = RuntimeError.new('test')
          expect(serf).to receive(:event).with(
            'mamiya-fetch-error',
            {
              name: serf.name, application: 'app', package: 'package',
              error: error.inspect,
            }.to_json,
          )

          callback.call(error)
        end

        it "updates tag" do
          allow(fetcher).to receive(:enqueue) do |&block|
            block.call(Exception.new)
          end

          expect(agent).to receive(:update_tags)
          trigger_fetch_request
        end
      end
    end
  end
end
