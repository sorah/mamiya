require 'spec_helper'
require 'mamiya/storages'
require 'mamiya/storages/abstract'

describe Mamiya::Storages do
  describe ".find" do
    let(:name) { :abstract }
    subject { Mamiya::Storages.find(name) }

    it "finds class by the name" do
      expect(subject).to eq Mamiya::Storages::Abstract
    end

    context "when not exists yet" do
      let(:name) { :shouldnt_exist }

      context "if load suceeded" do
        let(:klass) { Class.new }

        before do
          expect(Mamiya::Storages).to receive(:require) \
            .with('mamiya/storages/shouldnt_exist') do
            stub_const('Mamiya::Storages::ShouldntExist', klass)
          end
        end

        it "returns loaded constant" do
          expect(subject).to eq klass
        end
      end
    end
  end
end
