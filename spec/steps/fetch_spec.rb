require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'
require 'json'

require 'mamiya/package'
require 'mamiya/storages/mock'

require 'mamiya/steps/fetch'

describe Mamiya::Steps::Fetch do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-fetch-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:package_dir)     { Pathname.new(tmpdir).join('pkg').tap(&:mkdir) }
  let(:destination_dir) { Pathname.new(tmpdir).join('dst').tap(&:mkdir) }

  let(:package_name) { 'test' }
  let(:package_path) { package_dir.join("#{package_name}.tar.gz") }

  let(:package2_name) { 'test2' }
  let(:package2_path) { package_dir.join("#{package2_name}.tar.gz") }


  let(:script) do
    double('script',
      application: 'another',
    )
  end

  let(:config_source) do
    { storage: {} }
  end

  let(:config) do
    double('config',
      storage_class: Mamiya::Storages::Mock
    ).tap do |_|
      allow(_).to receive(:[]) do |k|
        config_source[k]
      end
    end
  end

  let(:options) do
    {package: package_name, application: 'app', destination: destination_dir.to_s}
  end

  subject(:fetch_step) { described_class.new(script: script, config: config, **options) }

  describe "#run!" do
    before do
      File.write package_path, "\n"
      File.write(package_path.to_s.gsub(/\.tar\.gz$/,'.json'),
                 {'name' => 'test', 'application' => 'app'}.to_json)

      File.write package2_path, "\n"
      File.write(package2_path.to_s.gsub(/\.tar\.gz$/,'.json'),
                 {'name' => 'test2', 'application' => 'another'}.to_json)


      Mamiya::Storages::Mock.new(application: 'app').push(
        Mamiya::Package.new(package_path))
      Mamiya::Storages::Mock.new(application: 'another').push(
        Mamiya::Package.new(package2_path))
    end

    it "fetches package from storage" do
      fetch_step.run!
      expect(destination_dir.join("#{package_name}.tar.gz")).to be_exist
    end

    context "when options[:application] is nil" do
      let(:options) do
        {package: package2_name, destination: destination_dir.to_s}
      end

      it "takes application name from script if available" do
        fetch_step.run!
        expect(destination_dir.join("#{package2_name}.tar.gz")).to be_exist
        expect(destination_dir.join("#{package_name}.tar.gz")).not_to be_exist

        expect(JSON.parse(destination_dir.join("#{package2_name}.json").read)['application']).to eq 'another'
      end
    end

    context "with verify option" do
      it "verifies "
    end

    context "when package not exists" do
      it "-"
    end
  end
end
