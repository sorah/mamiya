require 'spec_helper'
require 'mamiya/storages'

require 'mamiya/config'

describe Mamiya::Config do
  let(:source) do
    {
      "test" => {
        "a" => ["b" => {"c" => {"d" => "e"}}]
      },
      :test2 => :hello
    }
  end
  subject(:config) { described_class.new(source) }

  describe ".load" do
    let(:fixture_path) { File.join(__dir__, 'fixtures', 'test.yml') }

    subject(:config) { described_class.load(fixture_path) }

    it { should be_a(described_class) }

    it "loads configuration from file" do
      expect(config[:a][:e]).to eq "f"
    end
  end

  it "symbolizes keys" do
    expect(config[:test][:a][0][:b][:c][:d]).to eq "e"
    expect(config[:test2]).to eq :hello
  end

  describe "#storage_class" do
    let(:source) do
      {storage: {type: :foobar, conf: :iguration}}
    end
    let(:klass) { Class.new }

    before do
      allow(Mamiya::Storages).to receive(:find).with(:foobar).and_return(klass)
    end

    subject(:storage_class) { config.storage_class }

    it "finds class using Storages.find" do
      expect(storage_class).to eq klass
    end
  end
end
