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

    describe "packaging" do
      subject(:build) { build_step.run! }
      let(:package) { build; Dir[package_dir.join('*.tar.bz2').to_s].first }

      def extract!
        expect(package).not_to be_nil
        expect(Pathname.new(package)).to be_exist

        Dir.chdir(extract_dir) do
          system "tar", "xf", package
        end
      end

      it "creates a package to :build_to dir" do
        expect {
          build_step.run!
        }.to change {
          Dir[package_dir.join('*.tar.bz2').to_s].size
        }.from(0).to(1)
      end

      it "includes file in build_dir" do
        extract!
        expect(extract_dir.join('greeting').read).to eq 'hello'
      end

      it "excludes SCM directories" do
        build_dir.join('.git', 'test').write("test\n")
        build; extract!

        expect(extract_dir.join('.git')).not_to be_exist
      end

      context "with exclude_from_package option" do
        let(:exclude_from_package) { ['foo', 'hoge*'] }

        before do
          build_dir.join('foo').write("test\n")
          build_dir.join('hogefuga').write("test\n")

          build; extract!
        end

        it "excludes matched files from package" do
          expect(extract_dir.join('foo')).not_to be_exist
          expect(extract_dir.join('hogefuga')).not_to be_exist
          expect(extract_dir.join('greeting').read).to eq 'hello'
        end
      end

      context "with package_under option" do
        let(:package_under) { 'dir' }

        before do
          build_dir.join('dir').mkdir

          build_dir.join('root').write("shouldnt-be-included\n")
          build_dir.join('dir', 'greeting').write("hola\n")

          build; extract!
        end

        it "packages under specified directory" do
          expect(extract_dir.join('root')).not_to be_exist
          expect(extract_dir.join('greeting').read).to eq "hola\n"
        end
      end

      context "with dereference_symlinks option" do
        before do
          build_dir.join('target').write("I am target\n")
          build_dir.join('alias').make_symlink('target')

          build; extract!
        end

        context "when the option is true" do
          let(:dereference_symlinks) { true }

          it "dereferences symlinks for package" do
            expect(extract_dir.join('alias')).to be_exist
            expect(extract_dir.join('alias')).not_to be_symlink
            expect(extract_dir.join('alias').read).to eq "I am target\n"
          end
        end

        context "when the option is false" do
          let(:dereference_symlinks) { false }

          it "doesn't dereference symlinks" do
            expect(extract_dir.join('alias')).to be_exist
            expect(extract_dir.join('alias')).to be_symlink
            realpath = extract_dir.join('alias').realpath.relative_path_from(extract_dir).to_s
            expect(realpath).to eq './target'
          end
        end
      end

      context "with package name determiner" do
        it "delegates package naming to the determiner"
      end
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
