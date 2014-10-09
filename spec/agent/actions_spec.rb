require 'spec_helper'

require 'json'
require 'villein/event'

require 'mamiya/agent'
require 'mamiya/agent/actions'

require_relative '../support/dummy_serf.rb'

describe Mamiya::Agent::Actions do
  let(:serf) { DummySerf.new }

  let(:config) do
    {serf: {agent: {rpc_addr: '127.0.0.1:17373', bind: '127.0.0.1:17946'}}}
  end

  before do
    allow(Villein::Agent).to receive(:new).and_return(serf)
  end

  subject(:agent) { Mamiya::Agent.new(config) }


  describe "#distribute" do
    it "sends fetch request" do
      expect(agent).to receive(:trigger).with('task', task: 'fetch', app: 'myapp', pkg: 'mypkg', coalesce: false)

      agent.distribute('myapp', 'mypkg')
    end

    context "with labels" do
      it "adds _labels on task" do
        expect(agent).to receive(:trigger).with('task', task: 'fetch', app: 'myapp', pkg: 'mypkg', _labels: ['foo'], coalesce: false)

        agent.distribute('myapp', 'mypkg', labels: ['foo'])
      end
    end
  end

  describe "#prepare" do
    it "sends prepare request" do
      expect(agent).to receive(:trigger).with('task', task: 'prepare', app: 'myapp', pkg: 'mypkg', coalesce: false)

      agent.prepare('myapp', 'mypkg')
    end

    context "with labels" do
      it "adds _labels on task" do
        expect(agent).to receive(:trigger).with('task', task: 'prepare', app: 'myapp', pkg: 'mypkg', _labels: ['foo'], coalesce: false)

        agent.prepare('myapp', 'mypkg', labels: ['foo'])
      end
    end
  end


  describe "#switch" do
    it "sends switch request" do
      expect(agent).to receive(:trigger).with('task', task: 'switch', app: 'myapp', pkg: 'mypkg', coalesce: false, no_release: false, do_release: false)

      agent.switch('myapp', 'mypkg')
    end

    context "with no_release" do
      it "sends switch request" do
        expect(agent).to receive(:trigger).with('task', task: 'switch', app: 'myapp', pkg: 'mypkg', coalesce: false, no_release: true, do_release: false)

        agent.switch('myapp', 'mypkg', no_release: true)
      end
    end

    context "with no_release" do
      it "sends switch request" do
        expect(agent).to receive(:trigger).with('task', task: 'switch', app: 'myapp', pkg: 'mypkg', coalesce: false, no_release: false, do_release: true)

        agent.switch('myapp', 'mypkg', do_release: true)
      end
    end

    context "with labels" do
      it "adds _labels on task" do
        expect(agent).to receive(:trigger).with('task', task: 'switch', app: 'myapp', pkg: 'mypkg', _labels: ['foo'], coalesce: false, no_release: false, do_release: false)

        agent.switch('myapp', 'mypkg', labels: ['foo'])
      end
    end
  end

  describe "#ping" do
    it "pings cluster" do
      expect(agent).to receive(:trigger).with('task', task: 'ping', coalesce: false)

      agent.ping
    end
  end
end
