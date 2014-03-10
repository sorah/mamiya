require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'

require 'mamiya/steps/build'


describe Mamiya::Steps::Build do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-build-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:build_dir)   { Pathname.new(tmpdir).join('build') }
  let(:package_dir) { Pathname.new(tmpdir).join('pkg') }
  let(:extract_dir) { Pathname.new(tmpdir).join('extract') }

  let(:exclude_from_package) { [] }
  let(:package_under) { nil }
  let(:solve_symlinks) { false }
  let(:skip_prepare_build) { false }

  let(:config) do
    double('config',
      build_from: build_dir,
      build_to: package_dir,
      before_build: proc {},
      prepare_build: proc {},
      build: proc {},
      after_build: proc {},
      package_under: package_under,
      solve_symlinks: solve_symlinks,
      exclude_from_package: exclude_from_package,
      skip_prepare_build: skip_prepare_build,
    )
  end
  
  subject(:build_step) { described_class.new(config) }

  describe "#run!" do
    before do
      Dir.mkdir(build_dir)
      Dir.mkdir(package_dir)
      Dir.mkdir(extract_dir)

      File.write(build_dir.join('greeting'), 'hello')
    end

    it "calls hooks with proper order" do
      hooks = %i(before_build prepare_build build after_build)

      flags = []
      hooks.each do |sym|
        config.stub(sym, proc { flags << sym })
      end

      expect { build_step.run! }.
        to change { flags }.
        from([]).
        to(hooks)
    end

    it "calls build hook in :build_from (pwd)" do
      pwd = nil
      config.stub(build: proc { pwd = Dir.pwd })

      build_step.run!

      expect(pwd).to eq config.build_from
    end

    it "builds package"
    it "builds package after :build called"

    context "with package name determiner" do
      it "delegates package naming to the determiner"
    end

    context "when build_from directory exist" do
      it "calls prepare_build with update=true" do
        arg = nil
        config.stub(:prepare_build, proc { |update| arg = update })

        expect {
          build_step.run!
        }.to change { arg }.
          from(nil).to(true)
      end
    end

    context "when build_from directory doesn't exist" do
      before do
        FileUtils.remove_entry_secure(build_dir)
      end

      it "calls prepare_build with update=false" do
        arg = nil
        config.stub(:prepare_build, proc { |update| arg = update })

        expect {
          begin
            build_step.run!
          rescue Errno::ENOENT; end
        }.to change { arg }.
          from(nil).to(false)
      end

      it "raises error" do
        expect {
          build_step.run!
        }.to raise_error(Errno::ENOENT)
      end
    end

    it "creates package using Package"

    context "with skip_prepare_build option" do
      context "when the option is false" do
        let(:skip_prepare_build) { false }

        it "calls prepare_build" do
          flag = false
          config.stub(:prepare_build, proc { flag = true })

          expect { build_step.run! }.to change { flag }.
            from(false).to(true)
        end
      end

      context "when the option is true" do
        let(:skip_prepare_build) { true }

        it "doesn't call prepare_build" do
          flag = false
          config.stub(:prepare_build, proc { flag = true })

          expect { build_step.run! }.not_to change { flag }
        end
      end
    end
  end
end
