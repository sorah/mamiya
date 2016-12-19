require 'spec_helper'
require 'aws-sdk-core'
require 'mamiya/package'
require 'mamiya/storages/abstract'
require 'mamiya/storages/s3'
require 'tmpdir'
require 'fileutils'
require 'stringio'

describe Mamiya::Storages::S3 do
  before(:suite) do
    %w(AWS_ACCESS_KEY AWS_ACCESS_KEY_ID AMAZON_ACCESS_KEY_ID
       AWS_SECRET_KEY AWS_SECRET_ACCESS_KEY AMAZON_SECRET_ACCESS_KEY
       AWS_SESSION_TOKEN AMAZON_SESSION_TOKEN).each do |key|
      ENV.delete key
    end
  end

  let(:bucket) { 'testbucket' }
  let(:config) do
    {
      application: 'myapp',
      bucket: bucket,
      foo: :bar,
      access_key_id: 'AKI',
      secret_access_key: 'secret',
      region: 'ap-northeast-1'
    }
  end
  subject(:storage) { described_class.new(config) }

  let(:s3) do
    double('s3',
      put_object: nil,
      head_object: nil,
      list_objects: nil,
      delete_objects: nil
    )
  end

  before do
    allow(Aws::S3::Client).to receive(:new).with(foo: :bar, access_key_id: 'AKI', secret_access_key: 'secret', region: 'ap-northeast-1').and_return(s3)
  end

  describe "#push(package)" do
    let!(:tmpdir) { Dir.mktmpdir("mamiya-package-spec") }
    let(:tarball) { File.join(tmpdir, 'test.tar.gz') }
    let(:metafile) { File.join(tmpdir, 'test.json') }
    before do
      File.write tarball, "aaaaa\n"
      File.write File.join(tmpdir, 'test.json'), "{}\n"
    end
    after { FileUtils.remove_entry_secure tmpdir }

    let(:package) { double('package', :kind_of? => true, :exists? => true, path: tarball, meta_path: metafile, name: 'test') }

    it "uploads package to S3" do
      allow(s3).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new(nil, ''))

      expect(s3).to receive(:put_object) do |options|
        expect(options[:bucket]).to eq 'testbucket'
        expect(options[:key]).to eq "myapp/test.tar.gz"
        expect(options[:body]).to be_a_kind_of(File)
        expect(options[:body].path).to eq tarball
      end

      expect(s3).to receive(:put_object) do |options|
        expect(options[:bucket]).to eq 'testbucket'
        expect(options[:key]).to eq "myapp/test.json"
        expect(options[:body]).to be_a_kind_of(File)
        expect(options[:body].path).to eq metafile
      end

      storage.push package
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
      it "raises error" do
        allow(s3).to receive(:head_object).with(bucket: 'testbucket', key: 'myapp/test.tar.gz').and_return(double('response'))

        expect {
          storage.push(package)
        }.to raise_error(Mamiya::Storages::Abstract::AlreadyExists)
      end
    end
  end

  describe "#fetch(package_name, dir)" do
    let!(:tmpdir) { Dir.mktmpdir("mamiya-package-spec") }
    after { FileUtils.remove_entry_secure tmpdir }

    let(:tarball) { File.join(tmpdir, 'test.tar.gz') }
    let(:metafile) { File.join(tmpdir, 'test.json') }

    let(:package_name) { 'test' }
    subject(:fetch) { storage.fetch(package_name, tmpdir) }

    it "retrieves package from S3" do
      requests = []
      expect(s3).to receive(:get_object).twice do |options, send_options|
        requests << [options, send_options]
        if options[:key] && send_options[:target] &&
           options[:key].end_with?('.json') && send_options[:target].kind_of?(IO)
          expect(send_options[:target]).to be_binmode
          send_options[:target].puts "{}"
        end
      end

      fetch

      options, send_options = requests.shift
      expect(options[:bucket]).to eq 'testbucket'
      expect(options[:key]).to eq "myapp/test.tar.gz"
      expect(send_options[:target]).to be_a_kind_of(File)
      expect(send_options[:target].path).to eq("#{tarball}.fetching")

      options, send_options = requests.shift
      expect(options[:bucket]).to eq 'testbucket'
      expect(options[:key]).to eq "myapp/test.json"
      expect(send_options[:target]).to be_a_kind_of(File)
      expect(send_options[:target].path).to eq("#{metafile}.fetching")
    end

    it "returns Mamiya::Package" do
      allow(s3).to receive(:get_object) do
        File.write "#{metafile}.fetching", "{}\n"
      end

      expect(fetch).to be_a_kind_of(Mamiya::Package)
      expect(File.realpath(fetch.path)).to eq File.realpath(tarball)
    end

    context "when not found" do
      before do
        allow(s3).to receive(:get_object).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, ''))
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
        expect(s3).to receive(:get_object).with(
          hash_including(bucket: 'testbucket', key: 'myapp/test.tar.gz'), hash_including(target: an_instance_of(File)))
        expect(s3).to receive(:get_object).with(
          hash_including(bucket: 'testbucket', key: 'myapp/test.json'), hash_including(target: an_instance_of(File))) do
          File.write "#{metafile}.fetching", "{}\n"
        end

        fetch
      end
    end

    context "when name has .tar.gz" do
      let(:package_name) { 'test.tar.gz' }

      it "retrieves package" do
        expect(s3).to receive(:get_object).with(
          hash_including(bucket: 'testbucket', key: 'myapp/test.tar.gz'), hash_including(target: an_instance_of(File)))
        expect(s3).to receive(:get_object).with(
          hash_including(bucket: 'testbucket', key: 'myapp/test.json'), hash_including(target: an_instance_of(File))) do
          File.write "#{metafile}.fetching", "{}\n"
        end

        fetch
      end
    end
  end

  describe "#meta(package_name)" do
    let(:package_name) { 'test' }
    subject(:meta) { storage.meta(package_name) }

    before do
      allow(s3).to receive(:get_object).with(bucket: 'testbucket', key: 'myapp/test.json').and_return(
        double("response", body: StringIO.new({"foo" => "bar"}.to_json, "r").tap(&:read))
      )
    end

    it "retrieves meta JSON from S3" do
      expect(meta).to eq("foo" => "bar")
    end

    context "when not found" do
      before do
        allow(s3).to receive(:get_object).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, ''))
      end

      it "returns nil" do
        expect(meta).to be_nil
      end
    end

    context "when name has .json" do
      let(:package_name) { 'test.json' }

      it "retrieves meta JSON from S3" do
        expect(meta).to eq("foo" => "bar")
      end
    end

    context "when name has .tar.gz" do
      let(:package_name) { 'test.tar.gz' }

      it "retrieves meta JSON from S3" do
        expect(meta).to eq("foo" => "bar")
      end
    end
  end

  describe "#remove(package_name)" do
    let(:package_name) { 'test' }
    let(:s3_delete_response) { double('response for POST /?delete', errors: []) }
    subject(:remove) { storage.remove(package_name) }

    before do
      allow(s3).to receive(:head_object).and_return(double('response'))
    end

    it "removes specified package from S3" do
      expect(s3).to receive(:delete_objects).with(bucket: 'testbucket', delete: {objects: [{key: 'myapp/test.tar.gz'}, {key: 'myapp/test.json'}]}).and_return(s3_delete_response)
      remove
    end

    context "with name has .tar.gz" do
      let(:package_name) { 'test.tar.gz' }

      it "removes specified package from S3" do
        expect(s3).to receive(:delete_objects).with(bucket: 'testbucket', delete: {objects: [{key: 'myapp/test.tar.gz'}, {key: 'myapp/test.json'}]}).and_return(s3_delete_response)
        remove
      end
    end

    context "with name has .json" do
      let(:package_name) { 'test.json' }

      it "removes specified package from S3" do
        expect(s3).to receive(:delete_objects).with(bucket: 'testbucket', delete: {objects: [{key: 'myapp/test.tar.gz'}, {key: 'myapp/test.json'}]}).and_return(s3_delete_response)
        remove
      end
    end

    context "when not found" do
      before do
        allow(s3).to receive(:head_object).and_raise(Aws::S3::Errors::NotFound.new(nil, ''))
      end

      it "raises error" do
        expect { storage.remove('test') }.to raise_error(Mamiya::Storages::Abstract::NotFound)
      end
    end

    context "when delete_objects fails" do
      let(:errors) do
        [
          double('Aws::S3::Errors::InteranlError', code: 'InteranlError', message: 'Internal Error', key: 'myapp/test.tar.gz'),
          double('Aws::S3::Errors::AccessDenied', code: 'AccessDenied', message: 'Access Denied', key: 'myapp/test.json'),
        ]
      end
      let(:s3_delete_response) { double('response for POST /?delete', errors: errors) }

      it "raises error" do
        expect(s3).to receive(:delete_objects).with(bucket: 'testbucket', delete: {objects: [{key: 'myapp/test.tar.gz'}, {key: 'myapp/test.json'}]}).and_return(s3_delete_response)
        expect { remove }.to raise_error(Mamiya::Storages::S3::MultipleObjectsDeletionError, /Access Denied/)
      end
    end
  end

  describe ".find" do
    before do
      allow(s3).to receive(:list_objects).with(bucket: 'testbucket', delimiter: '/') \
        .and_return(
          double("object list",
                 common_prefixes: [
                   double("prefix1", prefix: 'myapp'),
                   double("prefix2", prefix: 'testapp')
                 ]
                )
        )
    end

    subject(:applications) { described_class.find(config.dup.tap{|_| _.delete(:application) }) }

    it "lists applications in S3" do
      expect(applications).to be_a_kind_of(Hash)
      expect(applications['myapp']).to be_a_kind_of(described_class)
      expect(applications['myapp'].application).to eq 'myapp'
      expect(applications['testapp']).to be_a_kind_of(described_class)
      expect(applications['testapp'].application).to eq 'testapp'
    end
  end

  describe "#packages" do
    before do
      allow(s3).to receive(:list_objects).with(bucket: 'testbucket', delimiter: '/', prefix: 'myapp/') \
        .and_return(
          double("object list",
                 contents: [
                   double("obj1.1", key: 'myapp/1.tar.gz'),
                   double("obj1.2", key: 'myapp/1.json'),
                   double("obj2.1", key: 'myapp/2.tar.gz'),
                   double("obj2.2", key: 'myapp/2.json'),
                   double("obj3.2", key: 'myapp/3.json'),
                   double("obj4.1", key: 'myapp/4.tar.gz'),
                 ]
                )
        )
    end

    subject(:packages) { storage.packages }

    it "lists packages in S3" do
      expect(packages).to eq ['1', '2']
    end
  end
end
