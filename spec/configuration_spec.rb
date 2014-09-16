require 'spec_helper'
require 'tmpdir'

require 'mamiya/dsl'
require 'mamiya/storages'

require 'mamiya/configuration'

describe Mamiya::Configuration do
  subject(:config) { described_class.new }

  it "inherits Mamiya::DSL" do
    expect(described_class.ancestors).to include(Mamiya::DSL)
  end

  describe "#storage_class" do
    before do
      config.evaluate! do
        set :storage, type: :foobar, conf: :iguration
      end
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

  describe "#deploy_to_for(app)" do
    before do
      config.evaluate! do
        applications[:myapp] = {deploy_to: '/apps/myapp'}
      end
    end

    it "returns deploy_to" do
      expect(config.deploy_to_for(:myapp)).to eq Pathname.new('/apps/myapp')
    end

    it "returns deploy_to" do
      expect(config.deploy_to_for('myapp')).to eq Pathname.new('/apps/myapp')
    end

    context "for nonexistent" do
      it "returns nil" do
      expect(config.deploy_to_for('nonexistent')).to be_nil
      expect(config.deploy_to_for(:nonexistent)).to be_nil
      end
    end
  end
end
