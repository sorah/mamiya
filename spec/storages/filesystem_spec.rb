require 'spec_helper'
require 'mamiya/package'
require 'mamiya/storages/abstract'
require 'mamiya/storages/filesystem'
require 'tmpdir'
require 'fileutils'
require 'json'

describe Mamiya::Storages::Filesystem do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-storages-filesystem-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:storage_path) { Pathname.new(tmpdir) }

  let(:config) do
    {
      application: 'myapp',
      path: storage_path.to_s,
    }
  end

  subject(:storage) { described_class.new(config) }

  describe "#push(package)" do
    let!(:source) { Dir.mktmpdir("mamiya-storages-fs-spec-push") }
    let(:tarball) { File.join(source, 'test.tar.gz') }
    let(:metafile) { File.join(source, 'test.json') }

    before do
      File.write tarball, "aaaaa\n"
      File.write File.join(tmpdir, 'test.json'), "{}\n"
    end

    after { FileUtils.remove_entry_secure source }

    let(:package) { double('package', :kind_of? => true, :exists? => true, path: tarball, meta_path: metafile, name: 'test') }

    it "places package on :path" do
    end

    context "when not built" do
      before do
        package.stub(:exists? => false)
      end

      it "raises error" do
        expect {
          storage.push(package)
        }.to raise_error(Mamiya::Storages::Abstract::NotBuilt)
      end
    end

    context "when already uploaded" do
      before do
        storage_path.join('myapp').mkpath
        File.write storage_path.join('myapp', 'test.tar.gz'), "aaaaa\n"
        File.write storage_path.join('myapp', 'test.json'), "{}\n"
      end

      it "raises error" do
        expect {
          storage.push(package)
        }.to raise_error(Mamiya::Storages::Abstract::AlreadyExists)
      end
    end
  end

  describe "#fetch(package_name, dir)" do
    let!(:destination) { Pathname.new Dir.mktmpdir("mamiya-storages-fs-destination") }
    after { FileUtils.remove_entry_secure destination }

    let(:tarball) { destination.join 'test.tar.gz' }
    let(:metafile) { destination.join 'test.json' }

    let(:package_name) { 'test' }
    subject(:fetch) { storage.fetch(package_name, destination) }

    before do
        storage_path.join('myapp').mkpath
      File.write storage_path.join('myapp', 'test.tar.gz'), "aaaaa\n"
      File.write storage_path.join('myapp', 'test.json'), "{}\n"
    end

    it "copies package from :path" do
      expect(tarball).not_to be_exist
      expect(metafile).not_to be_exist

      fetch

      expect(tarball).to be_exist
      expect(metafile).to be_exist
      expect(tarball.read).to eq "aaaaa\n"
      expect(metafile.read).to eq "{}\n"
    end

    it "returns Mamiya::Package" do
      expect(fetch).to be_a_kind_of(Mamiya::Package)
      expect(File.realpath(fetch.path)).to eq tarball.realpath.to_s
    end

    context "when not found" do
      before do
        storage_path.join('myapp', 'test.tar.gz').delete
        storage_path.join('myapp', 'test.json').delete
      end

      it "raises error" do
        expect {
          fetch
        }.to raise_error(Mamiya::Storages::Abstract::NotFound)
      end
    end

    context "when meta and tarball already exists" do
      before do
        File.write metafile, "\n"
        File.write tarball, "\n"
      end

      it "raises error" do
        expect {
          fetch
        }.to raise_error(Mamiya::Storages::Abstract::AlreadyFetched)
      end

      it "doesn't remove anything" do
        begin
          fetch
        rescue Mamiya::Storages::Abstract::AlreadyFetched; end

        expect(File.exist?(metafile)).to be_true
      end
    end

    context "when name has .json" do
      let(:package_name) { 'test.json' }

      it "retrieves package" do
        fetch

        expect(tarball.read).to eq "aaaaa\n"
        expect(metafile.read).to eq "{}\n"
      end
    end

    context "when name has .tar.gz" do
      let(:package_name) { 'test.tar.gz' }

      it "retrieves package" do
        fetch

        expect(tarball.read).to eq "aaaaa\n"
        expect(metafile.read).to eq "{}\n"
      end
    end
  end

  describe "#meta(package_name)" do
    let(:package_name) { 'test' }
    subject(:meta) { storage.meta(package_name) }

    before do
      storage_path.join('myapp').mkpath
      File.write storage_path.join('myapp', 'test.tar.gz'), "aaaaa\n"
      File.write storage_path.join('myapp', 'test.json'),
        "#{{"foo" => "bar"}.to_json}\n"
    end

    it "retrieves meta JSON from :path" do
      expect(meta).to eq("foo" => "bar")
    end

    context "when not found" do
      before do
        storage_path.join('myapp', 'test.tar.gz').delete
        storage_path.join('myapp', 'test.json').delete
      end

      it "returns nil" do
        expect(meta).to be_nil
      end
    end

    context "when name has .json" do
      let(:package_name) { 'test.json' }

      it "retrieves meta JSON from :path" do
        expect(meta).to eq("foo" => "bar")
      end
    end

    context "when name has .tar.gz" do
      let(:package_name) { 'test.tar.gz' }

      it "retrieves meta JSON from :path" do
        expect(meta).to eq("foo" => "bar")
      end
    end
  end

  describe "#remove(package_name)" do
    let(:package_name) { 'test' }
    subject(:remove) { storage.remove(package_name) }

    before do
      storage_path.join('myapp').mkpath
      File.write storage_path.join('myapp', 'test.tar.gz'), "aaaaa\n"
      File.write storage_path.join('myapp', 'test.json'), "{}\n"
    end

    it "removes specified package from :path" do
      remove

      expect(storage_path.join('myapp', 'test.tar.gz')).not_to be_exist
      expect(storage_path.join('myapp', 'test.json')).not_to be_exist
    end

    context "with name has .tar.gz" do
      let(:package_name) { 'test.tar.gz' }

      it "removes specified package from :path" do
        remove

        expect(storage_path.join('myapp', 'test.tar.gz')).not_to be_exist
        expect(storage_path.join('myapp', 'test.json')).not_to be_exist
      end
    end

    context "with name has .json" do
      let(:package_name) { 'test.json' }

      it "removes specified package from :path" do
        remove

        expect(storage_path.join('myapp', 'test.tar.gz')).not_to be_exist
        expect(storage_path.join('myapp', 'test.json')).not_to be_exist
      end
    end

    context "when not found" do
      before do
        storage_path.join('myapp', 'test.tar.gz').delete
        storage_path.join('myapp', 'test.json').delete
      end

      it "raises error" do
        expect { storage.remove('test') }.to raise_error(Mamiya::Storages::Abstract::NotFound)
      end
    end
  end

  describe ".find" do
    before do
      storage_path.join('myapp').mkpath
      storage_path.join('testapp').mkpath
    end

    subject(:applications) { described_class.find(config.dup.tap{|_| _.delete(:application) }) }

    it "lists applications in :path" do
      expect(applications).to be_a_kind_of(Hash)
      expect(applications['myapp']).to be_a_kind_of(described_class)
      expect(applications['myapp'].application).to eq 'myapp'
      expect(applications['testapp']).to be_a_kind_of(described_class)
      expect(applications['testapp'].application).to eq 'testapp'
    end
  end

  describe "#packages" do
    before do
      storage_path.join('myapp').mkpath
      File.write storage_path.join('myapp', '1.tar.gz'), "aaaaa\n"
      File.write storage_path.join('myapp', '1.json'), "{}\n"
      File.write storage_path.join('myapp', '2.tar.gz'), "aaaaa\n"
      File.write storage_path.join('myapp', '2.json'), "{}\n"
      File.write storage_path.join('myapp', '3.tar.gz'), "aaaaa\n"
      File.write storage_path.join('myapp', '4.json'), "{}\n"
    end

    subject(:packages) { storage.packages }

    it "lists packages in :path" do
      expect(packages).to eq ['1', '2']
    end
  end
end
