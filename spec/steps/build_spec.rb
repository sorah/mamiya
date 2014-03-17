require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'

require 'mamiya/package'

require 'mamiya/steps/build'

describe Mamiya::Steps::Build do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-build-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:build_dir)   { Pathname.new(tmpdir).join('build') }
  let(:package_dir) { Pathname.new(tmpdir).join('pkg') }
  let(:extract_dir) { Pathname.new(tmpdir).join('extract') }

  let(:exclude_from_package) { [] }
  let(:package_under) { nil }
  let(:dereference_symlinks) { false }
  let(:skip_prepare_build) { false }

  let(:script) do
    double('script',
      application: 'app',
      build_from: build_dir,
      build_to: package_dir,
      before_build: proc {},
      prepare_build: proc {},
      build: proc {},
      after_build: proc {},
      package_under: package_under,
      dereference_symlinks: dereference_symlinks,
      exclude_from_package: exclude_from_package,
      skip_prepare_build: skip_prepare_build,
    )
  end
  
  subject(:build_step) { described_class.new(script) }

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
        allow(script).to receive(sym).and_return(proc { flags << sym })
      end

      expect { build_step.run! }.
        to change { flags }.
        from([]).
        to(hooks)
    end

    it "calls build hook in :build_from (pwd)" do
      pwd = nil
      script.stub(build: proc { pwd = Dir.pwd })

      build_step.run!

      expect(File.realpath(pwd)).to eq script.build_from.realpath.to_s
    end

    it "creates package using Package after :build called" do
      built = false
      allow(script).to receive(:build).and_return(proc { built = true })
      allow(script).to receive(:exclude_from_package).and_return(['test'])
      allow(script).to receive(:dereference_symlinks).and_return(true)
      allow(script).to receive(:package_under).and_return('foo')

      expect_any_instance_of(Mamiya::Package).to \
        receive(:build!).with(
          build_dir,
          exclude_from_package: ['test'],
          dereference_symlinks: true,
          package_under: 'foo') {
        expect(built).to be_true
      }

      build_step.run!
    end

    context "with package name determiner" do
      it "delegates package naming to the determiner"
    end

    context "when build_from directory exist" do
      it "calls prepare_build with update=true" do
        arg = nil
        allow(script).to receive(:prepare_build).and_return(proc { |update| arg = update })

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
        allow(script).to receive(:prepare_build).and_return(proc { |update| arg = update })

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


    context "with skip_prepare_build option" do
      context "when the option is false" do
        let(:skip_prepare_build) { false }

        it "calls prepare_build" do
          flag = false
          allow(script).to receive(:prepare_build).and_return(proc { flag = true })

          expect { build_step.run! }.to change { flag }.
            from(false).to(true)
        end
      end

      context "when the option is true" do
        let(:skip_prepare_build) { true }

        it "doesn't call prepare_build" do
          flag = false
          allow(script).to receive(:prepare_build).and_return(proc { flag = true })

          expect { build_step.run! }.not_to change { flag }
        end
      end
    end
  end
end
