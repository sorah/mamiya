require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'digest/sha2'
require 'json'

require 'mamiya/package'

describe Mamiya::Package do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-package-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:build_dir)   { Pathname.new(tmpdir).join('build') }
  let(:extract_dir) { Pathname.new(tmpdir).join('extract') }
  before do
    build_dir.mkdir
    extract_dir.mkdir
  end

  let(:package_path) { File.join(tmpdir, 'test.tar.gz') }
  let(:meta_path)    { package_path.sub(/tar\.gz$/, "json") }

  let(:arg) { package_path }

  subject(:package) {
    Mamiya::Package.new(arg)
  }

  describe "#initialize" do
    context "without file extension" do
      it "accepts" do
        expect { described_class.new('foo') }.not_to raise_error
      end
    end

    context "with .tar.gz" do
      it "accepts" do
        expect { described_class.new('foo.tar.gz') }.not_to raise_error
      end
    end

    context "with .json" do
      it "accepts" do
        expect { described_class.new('foo.json') }.not_to raise_error
      end
    end
  end

  describe "#path" do
    subject { package.path }
    it { is_expected.to eq Pathname.new(package_path) }

    context "without file extension" do
      let(:arg) { 'test' }
      it { is_expected.to eq Pathname.new('test.tar.gz') }
    end

    context "with .tar.gz" do
      let(:arg) { 'test.tar.gz' }
      it { is_expected.to eq Pathname.new('test.tar.gz') }
    end

    context "with .json" do
      let(:arg) { 'test.json' }
      it { is_expected.to eq Pathname.new('test.tar.gz') }
    end

    context "with filename containing dot" do
      let(:arg) { 'a.b' }
      it { is_expected.to eq Pathname.new('a.b.tar.gz') }
    end
  end

  describe "#meta_path" do
    subject { package.meta_path }

    context "without file extension" do
      let(:arg) { 'test' }
      it { is_expected.to eq Pathname.new('test.json') }
    end

    context "with .tar.gz" do
      let(:arg) { 'test.tar.gz' }
      it { is_expected.to eq Pathname.new('test.json') }
    end

    context "with .json" do
      let(:arg) { 'test.json' }
      it { is_expected.to eq Pathname.new('test.json') }
    end

    context "with filename containing dot" do
      let(:arg) { 'a.b' }
      it { is_expected.to eq Pathname.new('a.b.json') }
    end
  end

  describe "#extract_onto!(path)" do
    subject { package.extract_onto!(extract_dir) }

    context "with package" do
      before do
        File.write build_dir.join("greeting"), "hello\n"
        Dir.chdir(build_dir) {
          system "tar", "cjf", package_path, '.'
        }
      end

      context "when directory exists" do
        it "extracts onto specified directory" do
          expect {
            package.extract_onto!(extract_dir)
          }.to change {
            extract_dir.join('greeting').exist?
          }.from(false).to(true)

          expect(extract_dir.join('greeting').read).to eq "hello\n"
        end
      end

      context "when directory not exists" do
        before do
          FileUtils.remove_entry_secure extract_dir
        end

        it "creates directory" do
          expect {
            package.extract_onto!(extract_dir)
          }.to change {
            extract_dir.exist?
          }.from(false).to(true)

          expect(extract_dir.join('greeting').read).to eq "hello\n"
        end
      end
    end

    context "without package" do
      it "raises error" do
        expect {
          package.extract_onto!(extract_dir)
        }.to raise_error(Mamiya::Package::NotExists)
      end
    end
  end

  describe "#valid?" do
    subject { package.valid? }

    it "verifies signature"

    context "when checksum is correct" do
      before do
        File.write(package_path, "test\n")
        File.write(meta_path, {"checksum" => Digest::SHA2.hexdigest("test\n")}.to_json + "\n")
      end

      it { is_expected.to be true }
    end

    context "when checksum is incorrect" do
      before do
        File.write(package_path, "wrong\n")
        File.write(meta_path, {"checksum" => Digest::SHA2.hexdigest("text\n")}.to_json + "\n")
      end

      it { is_expected.to be false }
    end

    context "when package not exists" do
      it "raises error" do
        expect { subject }.to raise_error(Mamiya::Package::NotExists)
      end
    end

    context "when package meta json not exists" do
      before do
        File.write package_path, "\n"
      end

      it "raises error" do
        expect { subject }.to raise_error(Mamiya::Package::NotExists)
      end
    end
  end

  describe "#name" do
    subject { package.name }

    it { is_expected.to eq 'test' }

    context "when meta['name'] exists" do
      before do
        package.meta['name'] = 'pack'
      end

      it { is_expected.to eq 'pack' }
    end
  end

  describe "#application" do
    subject { package.application }

    it { is_expected.to eq nil }

    context "when meta['application'] exists" do
      before do
        package.meta['application'] = 'app'
      end

      it { is_expected.to eq 'app' }
    end
  end

  describe "#checksum" do
    subject { package.checksum }

    it { is_expected.to be_nil }

    context "when package exists" do
      before do
        File.write package_path, "text\n"
      end

      it { is_expected.to eq Digest::SHA2.hexdigest("text\n") }
    end
  end

  describe "#exists?" do
    subject { package.exists? }

    context "when package exists" do
      before do
        File.write package_path, ''
      end

      it { is_expected.to be true }
    end

    context "when package not exists" do
      before do
        File.unlink(package_path) if File.exists?(package_path)
      end

      it { is_expected.to be false }
    end
  end

  describe "#sign!" do
    it "signs package"
  end

  describe "#build!(build_dir)" do
    let(:dereference_symlinks) { nil }
    let(:exclude_from_package) { nil }
    let(:package_under) { nil }

    let(:build) {
      kwargs = {}
      kwargs[:dereference_symlinks] = dereference_symlinks unless dereference_symlinks.nil?
      kwargs[:exclude_from_package] = exclude_from_package unless exclude_from_package.nil?
      kwargs[:package_under] = package_under unless package_under.nil?
      package.build!(
        build_dir,
        **kwargs
      )
    }

    before do
      File.write(build_dir.join('greeting'), 'hello')
    end

    def build_then_extract!
      build

      expect(Pathname.new(package_path)).not_to be_nil

      system "tar", "xf", package_path, "-C", extract_dir.to_s
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
      build_dir.join('.git').mkdir
      File.write build_dir.join('.git', 'test'), "test\n"
      build_then_extract!

      expect(extract_dir.join('.git')).not_to be_exist
    end

    it "includes deploy script itself"

    it "saves meta file" do
      package.meta = {"a" => 1, "b" => {"c" => ["d", "e"]}}
      packed_meta = package.meta.dup

      build_then_extract!

      expect(package.meta["checksum"]).to eq Digest::SHA2.file(package_path).hexdigest

      meta_path_in_build = extract_dir.join('.mamiya.meta.json')
      packed_meta['name'] = package.meta['name']
      json = JSON.parse(File.read(meta_path_in_build))
      expect(json).to eq JSON.parse(packed_meta.to_json)

      json = JSON.parse(File.read(meta_path))
      expect(json).to eq JSON.parse(package.meta.to_json)
    end

    it "doesn't leave meta file in build_dir" do
      package.meta = {"a" => 1, "b" => {"c" => ["d", "e"]}}
      build

      expect(build_dir.join('.mamiya.meta.json')).not_to be_exist
    end

    context "with exclude_from_package option" do
      let(:exclude_from_package) { ['foo', 'hoge*'] }

      before do
        File.write build_dir.join('foo'), "test\n"
        File.write build_dir.join('hogefuga'), "test\n"

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

        File.write build_dir.join('root'), "shouldnt-be-included\n"
        File.write build_dir.join('dir', 'greeting'), "hola\n"

        build_then_extract!
      end

      it "packages under specified directory" do
        expect(extract_dir.join('root')).not_to be_exist
        expect(extract_dir.join('greeting').read).to eq "hola\n"
      end
    end

    context "with dereference_symlinks option" do
      before do
        File.write build_dir.join('target'), "I am target\n"
        build_dir.join('alias').make_symlink('target')

        build_then_extract!
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
          realpath = extract_dir.join('alias').realpath.relative_path_from(extract_dir.realpath).to_s
          expect(realpath).to eq 'target'
        end
      end
    end
  end
end
