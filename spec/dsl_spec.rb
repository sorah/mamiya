require 'spec_helper'
require 'mamiya/dsl'
require 'mamiya/util/label_matcher'

describe Mamiya::DSL do
  let(:klass) { Class.new(Mamiya::DSL) }
  subject(:dsl) { klass.new }

  describe ".set_default" do
    it "sets default" do
      expect { dsl.testvar }.to raise_error
      klass.set_default :testvar, 1
      expect(dsl.testvar).to eq 1
    end
  end

  describe ".add_hook" do
    it "adds hook" do
      expect { dsl.testhook }.to raise_error
      klass.add_hook :testhook
      expect(dsl.testhook).to be_a(Proc)
    end
  end

  describe "#evaluate!" do
    context "with block" do
      it "evaluates block within its object" do
        flag = false
        expect {
          dsl.evaluate! { flag = true }
        }.to change { flag }.from(false).to(true)
      end
    end

    context "with string" do
      it "evaluates string within its object" do
        expect(dsl).to receive(:flag!)
        dsl.evaluate! "flag!"
      end
    end
  end

  describe "#load!" do
    before do
      dsl.set :foo, 42
    end

    it "loads file" do
      expect {
        dsl.load! "#{__dir__}/fixtures/dsl_test_load.rb"
      }.to change { dsl.foo }.from(42).to(72)
    end

    it "sets _file" do
      expect {
        dsl.load! "#{__dir__}/fixtures/dsl_test_load.rb"
      }.to change { dsl._file }.from(nil).to("#{__dir__}/fixtures/dsl_test_load.rb")
    end
  end

  describe "#use" do
    before do
      dsl.set :foo, 42
    end

    it "loads file" do
      dsl.set :load_path, ["#{__dir__}/fixtures/helpers"]
      expect {
        dsl.use :foo
      }.to change { dsl.foo }.from(42).to(72)
    end

    context "when file not exists" do
      it "raises error" do
        expect {
          dsl.use :blahblahblah
        }.to raise_error(Mamiya::DSL::HelperNotFound)
      end
    end

    context "with options" do
      it "passes to file" do
        dsl.set :load_path, ["#{__dir__}/fixtures/helpers"]
        expect {
          dsl.use :foo, value: 100
        }.to change { dsl.foo }.from(42).to(100)
      end
    end
    
    context "when loading file" do
      it "loads file with suitable load path" do
        expect {
          dsl.load! "#{__dir__}/fixtures/dsl_test_use.rb"
        }.to change { dsl.foo }.from(42).to(72)
      end
    end
  end

  describe "#set" do
    it "sets variable" do
      expect{ dsl.foo }.to raise_error
      dsl.set :foo, 100
      expect(dsl.foo).to eq 100
      expect(dsl[:foo]).to eq 100
      dsl.set :foo, 200
      expect(dsl.foo).to eq 200
      expect(dsl[:foo]).to eq 200
    end
  end

  describe "#set_default" do
    it "sets variable" do
      dsl.set_default :foo, 100
      expect(dsl.foo).to eq 100
      expect(dsl[:foo]).to eq 100
    end

    context "when already assigned" do
      it "doesn't nothing" do
        dsl.set :foo, 100
        dsl.set_default :foo, 200
        expect(dsl.foo).to eq 100
        expect(dsl[:foo]).to eq 100
      end
    end
  end

  describe "tasks" do
    it "defines callable tasks" do
      flag = false
      dsl.task :test do
        flag = true
      end

      expect {
        dsl.invoke :test
      }.to change { flag }.from(false).to(true)
    end

    it "can be called from another tasks" do
      flag = false

      dsl.task :a do
        invoke :b
      end

      dsl.task :b do
        flag = true
      end

      expect {
        dsl.invoke :a
      }.to change { flag }.from(false).to(true)
    end

    context "when task doesn't exist" do
      it "raises error" do
        expect {
          dsl.invoke :nul
        }.to raise_error
      end
    end
  end

  describe "hook method" do
    before do
      klass.add_hook(:testhook)
    end

    context "without block" do
      it "returns Proc to run hooks" do
        expect(dsl.testhook).to be_a_kind_of(Proc)
      end
    end

    context "with block" do
      it "appends given block to hooks" do
        flag = false
        dsl.testhook { flag = true }
        expect { dsl.testhook.call }.to \
          change { flag }.from(false).to(true)
      end

      it "appends given block to hooks (multiple)" do
        flags = []
        dsl.testhook { flags << :a }
        dsl.testhook { flags << :b }

        expect { dsl.testhook.call }.to \
          change { flags }.from([]).to([:a,:b])
      end

      it "can call hooks with argument" do
        flag = nil
        dsl.testhook { |a| flag = a }

        expect { dsl.testhook.call(42) }.to \
          change { flag }.from(nil).to(42)
      end

      context "with :prepend" do
        it "prepends given block to hooks" do
          flag = nil
          dsl.testhook { |a| flag = 1 }
          dsl.testhook(:prepend) { flag = 0 }

          expect { dsl.testhook.call }.to \
            change { flag }.from(nil).to(1)
        end
      end

      context "with :overwrite" do
        it "overwrites all existing hooks with given block" do
          flags = []
          dsl.testhook { |a| flags << :a }
          dsl.testhook { |a| flags << :b }
          dsl.testhook(:overwrite) { |a| flags << :c }

          expect { dsl.testhook.call }.to \
            change { flags }.from([]).to([:c])
        end
      end
    end

    describe "limiting by label" do
      context "using kwarg :only" do
        it "runs only for specified label" do
          matcher = double('matcher')
          expect(Mamiya::Util::LabelMatcher::Simple).to receive(:new).with([:a,:b,:d]).and_return(matcher)
          expect(matcher).to receive(:match?).with(:a).and_return(true)
          expect(matcher).to receive(:match?).with([:a]).and_return(true)
          expect(matcher).to receive(:match?).with([:b, :c]).and_return(false)

          flags = []
          dsl.testhook(only: [:a]) { flags << 1 }
          dsl.testhook { flags << 2 }
          dsl.testhook(only: [[:b, :c]]) { flags << 3 }
          dsl.testhook(:prepend, only: [[:a]]) { flags << 4 }

          expect { dsl.testhook(:a, :b, :d).call }.to \
            change { flags }.from([]).to([4,1,2])
        end
      end

      context "using kwarg :except" do
        it "doesn't run for specified label" do
          matcher = double('matcher')
          expect(Mamiya::Util::LabelMatcher::Simple).to receive(:new).with([:a,:b,:d]).and_return(matcher)
          expect(matcher).to receive(:match?).with(:a).and_return(true)
          expect(matcher).to receive(:match?).with([:a]).and_return(true)
          expect(matcher).to receive(:match?).with([:b, :c]).and_return(false)

          flags = []
          dsl.testhook(except: [:a]) { flags << 1 }
          dsl.testhook { flags << 2 }
          dsl.testhook(except: [[:b, :c]]) { flags << 3 }
          dsl.testhook(:prepend, except: [[:a]]) { flags << 4 }

          expect { dsl.testhook(:a, :b, :d).call }.to \
            change { flags }.from([]).to([2,3])
        end
      end
    end

    describe "chain hooks" do
      before do
        klass.add_hook(:testchain, chain: true)
      end

      it "injects the result of blocks" do
        dsl.testchain { |result, arg| result += arg * 3 }
        dsl.testchain { |result, arg| result -= arg }

        expect(dsl.testchain[2, 5]).to eq 12
      end
    end

    describe "naming" do
      it "ables to name defined hooks" do
        dsl.testhook('the-name') { }
        expect(dsl.hooks[:testhook].first[:name]).to eq 'the-name'
      end

      context "with other option" do
        it "ables to name defined hooks" do
          dsl.testhook('the-name2', :prepend) { }
          dsl.testhook('the-name', :prepend) { }
          expect(dsl.hooks[:testhook].first[:name]).to eq 'the-name'
        end
      end
    end
  end

  describe "#servers" do
    pending "Hey!"
  end

  describe "#use_servers" do
    pending "Hey!"
  end
end
