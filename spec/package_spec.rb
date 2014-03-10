require 'spec_helper'
require 'tmpdir'
require 'pathname'

require 'mamiya/package'

describe Mamiya::Package do
  let(:package_path) { package_path }
  subject(:package) {
    Mamiya::Package.new(package_path)
  }

  describe "#path" do
  end

  describe "#extract" do
  end

  describe "#verify" do
  end

  describe "#name" do
  end

  describe "#checksum" do
  end

  describe "#meta" do
  end

  describe "#exist?" do
  end

  describe "#build!(build_dir)" do
    let!(:tmpdir) { Dir.mktmpdir("mamiya-package-spec") }
    after { FileUtils.remove_entry_secure tmpdir }

    let(:build_dir)   { Pathname.new(tmpdir).join('build') }
    let(:extract_dir) { Pathname.new(tmpdir).join('extract') }

    let(:build) { package.build!(build_dir) }

    def build_then_extract!
      build

      expect(Pathname.new(package_path)).not_to be_nil

      extract_dir.mkdir
      Dir.chdir(extract_dir) do
        system "tar", "xf", package
      end
    end

    it "creates a package to path" do
      expect {
        build
      }.to change {
        File.exist? package_path
      }.from(false).to(true)
    end

    it "includes file in build_dir" do
      build_then_extract!
      expect(extract_dir.join('greeting').read).to eq 'hello'
    end

    it "excludes SCM directories" do
      build_dir.join('.git', 'test').write("test\n")
      build_then_extract!

      expect(extract_dir.join('.git')).not_to be_exist
    end

    context "with exclude_from_package option" do
      let(:exclude_from_package) { ['foo', 'hoge*'] }

      before do
        build_dir.join('foo').write("test\n")
        build_dir.join('hogefuga').write("test\n")

        build_then_extract!
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
  end
end
