require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'
require 'json'

require 'mamiya/script'

require 'mamiya/package'
require 'mamiya/steps/switch'

describe Mamiya::Steps::Switch do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-switch-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:deploy_to) { Pathname.new(tmpdir) }
  let(:releases_dir) { deploy_to.join('releases').tap(&:mkdir) }

  let(:release_path) { releases_dir.join('20140907030907').tap(&:mkdir) }
  let(:current_path) { deploy_to.join('current') }

  let(:target_meta) do
    {script: 'script.rb'}
  end

  let(:script) do
    double('script',
      deploy_to: deploy_to,
      before_switch: proc {},
      release: proc {},
      after_switch: proc {},
      current_path: current_path,
    )
  end

  let(:config) do
    double('config')
  end

  let(:options) do
    {target: release_path, labels: [:foo, :bar]}
  end

  subject(:step) { described_class.new(script: nil, config: config, **options) }

  before do
    File.write release_path.join('.mamiya.meta.json'), target_meta.to_json
    allow(Mamiya::Script).to receive(:new).and_return(script)

    allow(script).to receive(:load!).with(release_path.realpath.join('.mamiya.script', 'script.rb')).and_return(script)
    allow(script).to receive(:set).and_return(script)
  end

  describe "#run!" do
    it "calls hooks with proper order" do
      hooks = %i(before_switch release after_switch)

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
      allow(script).to receive(:release).and_return(proc { raise e })

      received = nil
      allow(script).to receive(:after_switch).and_return(proc { |_| received = _ })

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
      script.stub(release: proc { pwd = Dir.pwd })

      expect {
        step.run!
      }.not_to change { Dir.pwd }

      expect(File.realpath(pwd)).to eq release_path.realpath.to_s
    end

    it "sets release_path" do
      expect(script).to receive(:set).with(:release_path, release_path.realpath)
      expect(script).to receive(:set).with(:logger, step.logger)
      step.run!
    end

    it "calls hooks using labels" do
      allow(script).to receive(:before_switch).with(%i(foo bar)).and_return(proc {})
      allow(script).to receive(:release).with(%i(foo bar)).and_return(proc {})
      allow(script).to receive(:after_switch).with(%i(foo bar)).and_return(proc {})

      step.run!
    end

    it "links current to release_path" do
      expect {
        step.run!
      }.to change {
        current_path.exist? ? current_path.realpath : nil
      }.from(nil).to(release_path.realpath)
    end

    context "when current already exists" do
      before do
          current_path.make_symlink('releases/20140515000707')
      end

      it "links current to release_path" do
        expect {
          step.run!
        }.to change {
          current_path.exist? ? current_path.realpath : nil
        }.to(release_path.realpath)
      end
    end

    context "with no_release" do
      let(:options) do
        {target: release_path, no_release: true}
      end

      it "doesn't call release" do
        called = false
        allow(script).to receive(:release).and_return(proc { called = true })
        step.run!

        expect(called).to be_false
      end
    end
  end
end
