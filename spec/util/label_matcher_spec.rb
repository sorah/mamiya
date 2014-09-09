require 'spec_helper'
require 'mamiya/util/label_matcher'

describe Mamiya::Util::LabelMatcher do
  describe ".parse_string_expr" do
    let(:str) { '' }
    subject { described_class.parse_string_expr(str) }

    it { should eq [] }

    describe "(simple)" do
      let(:str) { 'foo' }
      it { should eq [['foo']] }
    end

    describe "(and)" do
      let(:str) { 'foo,bar' }
      it { should eq [['foo','bar']] }
    end

    describe "(or)" do
      let(:str) { 'foo|bar' }
      it { should eq [['foo'],['bar']] }
    end

    describe "(and/or)" do
      let(:str) { 'foo,bar|baz' }
      it { should eq [['foo','bar'],['baz']] }
    end

    describe "(and/or 2)" do
      let(:str) { '1,2|3,4' }
      it { should eq [['1','2'],['3','4']] }
    end
  end

  describe "#match?(expression)" do
    let(:klass) {
      Class.new {
        include Mamiya::Util::LabelMatcher

        def initialize(labels)
          @labels = labels
        end

        attr_reader :labels
      }
    }

    let(:labels) { [:a, :b, :d] }
    let(:expression) { [] }
    subject { klass.new(labels).match?(*expression) }

    context "when expression is Array<Symbol>" do
      context "and match" do
        let(:expression) { [[:a, :d]] }
        it { should eq true }
      end

      context "and match (2)" do
        let(:expression) { [[:a]] }
        it { should eq true }
      end

      context "and not match" do
        let(:expression) { [[:a, :c]] }
        it { should eq false }
      end
    end

    context "when expression is Symbol" do
      context "and match" do
        let(:expression) { [:a] }
        it { should eq true }
      end

      context "and not match" do
        let(:expression) { [:c] }
        it { should eq false }
      end
    end

    context "when all expressions are Symbol" do
      context "and match" do
        let(:expression) { [:a, :b] }
        it { should eq true }
      end

      context "and not match" do
        let(:expression) { [:a, :c] }
        it { should eq false }
      end
    end

    context "when expression is Array<Array> (recursive call)" do
      describe "(case A)" do
        let(:expression) { [ [[:a, :c], [:b, :d]] ] }
        it { should eq true }
      end

      describe "(case B)" do
        let(:expression) { [ [[:a]] ] }
        it { should eq true }
      end

      describe "(case C)" do
        let(:expression) { [ [[:c]] ] }
        it { should eq false }
      end

      describe "(case D)" do
        let(:expression) { [ [[:a, :c], :b] ] }
        it { should eq true }
      end
    end
  end
end
