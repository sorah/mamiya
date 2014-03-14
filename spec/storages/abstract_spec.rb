require 'spec_helper'

require 'mamiya/storages/abstract'

describe Mamiya::Storages::Abstract do
  subject(:storage) { described_class.new }

  describe "#prune(nums_to_keep)" do
    before do
      allow(storage).to receive(:packages).and_return(%w(1 2 3 4 5 6 7))
    end

    it "discards old releases" do
      expect(storage).to receive(:remove).with('1')
      expect(storage).to receive(:remove).with('2')
      expect(storage).to receive(:remove).with('3')
      expect(storage).to receive(:remove).with('4')

      storage.prune(3)
    end
  end
end
