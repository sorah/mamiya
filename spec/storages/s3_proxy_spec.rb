require 'spec_helper'
require 'aws-sdk-core'
require 'mamiya/package'
require 'mamiya/storages/abstract'
require 'mamiya/storages/s3_proxy'
require 'mamiya/storages/s3'
require 'tmpdir'
require 'fileutils'
require 'stringio'

describe Mamiya::Storages::S3Proxy do
  let(:bucket) { 'testbucket' }

  let(:config) do
    {
      application: 'myapp',
      bucket: bucket,
      foo: :bar,
      access_key_id: 'AKI',
      secret_access_key: 'secret',
      region: 'ap-northeast-1',
      proxy_host: 'http://my-proxy:8080/_',
    }
  end
  subject(:storage) { described_class.new(config) }

  let(:http) do
    double('http').tap do |http|
      allow(http).to receive(:use_ssl=).with(false)
      allow(http).to receive(:start).and_yield(http)

      allow(http).to receive(:request_get).with('/_/testbucket/myapp/test.tar.gz').and_yield(
        double('tarball response').tap do |resp|
          allow(resp).to receive(:value).and_return(200)
          allow(resp).to receive(:read_body).and_yield("{}\n")
        end
      )

      allow(http).to receive(:request_get).with('/_/testbucket/myapp/test.json').and_yield(
        double('json response').tap do |resp|
          allow(resp).to receive(:value).and_return(200)
          allow(resp).to receive(:read_body).and_yield("{}\n")
        end
      )

      allow(http).to receive(:request_get).with('/_/testbucket/myapp/not-found.tar.gz').and_yield(
        double('tarball 404 response').tap do |resp|
          allow(resp).to receive(:value).and_raise(Net::HTTPServerException.new('404 "Not Found"',''))
        end
      )

      allow(http).to receive(:request_get).with('/_/testbucket/myapp/not-found.json').and_yield(
        double('json 404 response').tap do |resp|
          allow(resp).to receive(:value).and_raise(Net::HTTPServerException.new('404 "Not Found"',''))
        end
      )
    end
  end

  before do
    expect(Aws::S3).not_to receive(:new)
    allow(Net::HTTP).to receive(:new).with('my-proxy', 8080).and_return(http)
  end

  it "inherits S3 storage" do
    expect(described_class.ancestors).to include(Mamiya::Storages::S3)
  end

  describe "#fetch(package_name, dir)" do
    let!(:tmpdir) { Dir.mktmpdir("mamiya-package-spec") }
    after { FileUtils.remove_entry_secure tmpdir }

    let(:tarball) { File.join(tmpdir, 'test.tar.gz') }
    let(:metafile) { File.join(tmpdir, 'test.json') }

    let(:package_name) { 'test' }
    subject(:fetch) { storage.fetch(package_name, tmpdir) }

    it "retrieves package from S3" do
      expect(fetch).to be_a_kind_of(Mamiya::Package)
      expect(File.realpath(fetch.path)).to eq File.realpath(tarball)

      expect(File.read(tarball)).to eq "{}\n"
      expect(File.read(metafile)).to eq "{}\n"
    end


    context "when not found" do
      let(:package_name) { 'not-found' }

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

        expect(File.exist?(metafile)).to be true
      end
    end
  end

  #describe "#meta(package_name)" do
  #  let(:package_name) { 'test' }
  #  subject(:meta) { storage.meta(package_name) }

  #  it "retrieves meta JSON from S3" do
  #    expect(meta).to eq({})
  #  end

  #  context "when not found" do
  #    let(:package_name) { 'not-found' }

  #    it "returns nil" do
  #      expect(meta).to be_nil
  #    end
  #  end
  #end
end
