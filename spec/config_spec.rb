require 'spec_helper'

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
end
