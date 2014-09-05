require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'
require 'json'

require 'mamiya/script'

require 'mamiya/package'
require 'mamiya/steps/prepare'

describe Mamiya::Steps::Prepare do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-prepare-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:target_dir) { Pathname.new(tmpdir).join('release').tap(&:mkdir) }

  let(:target_meta) do
    {
      script: 'script.rb',
    }
  end

  let(:script) do
    double('script',
      before_prepare: proc {},
      prepare: proc {},
      after_prepare: proc {},
    )
  end

  let(:config) do
    double('config')
  end

  let(:options) do
    {target: target_dir, labels: [:foo, :bar]}
  end

  subject(:step) { described_class.new(script: nil, config: config, **options) }

  before do
    File.write target_dir.join('.mamiya.meta.json'), target_meta.to_json
    allow(Mamiya::Script).to receive(:new).and_return(script)
    allow(script).to receive(:load!).with(target_dir.realpath.join('.mamiya.script', 'script.rb')).and_return(script)
    allow(script).to receive(:set).and_return(script)
  end

  describe "#run!" do
    it "calls hooks with proper order" do
      hooks = %i(before_prepare prepare after_prepare)

      flags = []
      hooks.each do |sym|
        allow(script).to receive(sym).and_return(proc { flags << sym })
      end

      expect { step.run! }.
        to change { flags }.
        from([]).
        to(hooks)
    end

    it "calls after hook even if exception occured" do
      e = Exception.new("Good bye, the cruel world")
      allow(script).to receive(:prepare).and_return(proc { raise e })

      received = nil
      allow(script).to receive(:after_prepare).and_return(proc { |_| received = _ })

      expect {
        begin
          step.run!
        rescue Exception; end
      }.
        to change { received }.
        from(nil).to(e)
    end

    it "calls hook in :target (pwd)" do
      pwd = nil
      script.stub(prepare: proc { pwd = Dir.pwd })

      expect {
        step.run!
      }.not_to change { Dir.pwd }

      expect(File.realpath(pwd)).to eq target_dir.realpath.to_s
    end

    it "sets release_path" do
      expect(script).to receive(:set).with(:release_path, target_dir.realpath)
      expect(script).to receive(:set).with(:logger, step.logger)
      step.run!
    end

    it "calls hooks using labels" do
      allow(script).to receive(:before_prepare).with(%i(foo bar)).and_return(proc {})
      allow(script).to receive(:prepare).with(%i(foo bar)).and_return(proc {})
      allow(script).to receive(:after_prepare).with(%i(foo bar)).and_return(proc {})

      step.run!
    end
  end
end
