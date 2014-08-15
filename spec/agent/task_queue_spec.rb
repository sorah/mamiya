require 'spec_helper'

describe Mamiya::Agent::TaskQueue do
  let(:agent) do
    double('agent')
  end

  subject(:queue) do
    described_class.new(agent)
  end

  describe "lifecycle (#start!, #stop!)" do
    it "can start and stop"
    it "can stop gracefully"
  end

  describe "work loop (#enqueue, #running?, #working, #status)" do
    it "run enqueued task"

    describe "#status" do
      it "shows status"
    end

    context "with multiple task classes" do
      it "run enqueued task"

      describe "#status" do
        it "shows status for each task class"
      end
    end
  end
end
