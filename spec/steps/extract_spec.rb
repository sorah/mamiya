require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'

require 'mamiya/package'
require 'mamiya/steps/extract'

describe Mamiya::Steps::Extract do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-extract-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:package_dir) { Pathname.new(tmpdir).join('pkg').tap(&:mkdir) }

  let(:target_package) { package_dir.join('test-package.tar.gz').to_s }
  let(:script) do
    double('script',
      application: 'myapp',
    )
  end

  let(:destination) { Pathname.new(tmpdir).join('dst') }

  let(:options) do
    {
      package: target_package,
      destination: destination.to_s,
    }
  end

  subject(:extract_step) { described_class.new(script: script, **options) }

  describe "#run!" do
    before do
      FileUtils.cp File.join(__dir__, '..', 'fixtures', 'test-package.tar.gz'), target_package
      File.write target_package.gsub(/\.tar\.gz$/,'.json'), "{}\n"
    end

    context "when destination exists" do
      before do
        destination.mkdir()
        allow_any_instance_of(Mamiya::Package).to receive(:name).and_return('package-name')
      end

      it "extracts package on sub-directory named as same as package name" do
        extract_step.run!
        expect(destination.join('package-name')).to be_a_directory
        expect(destination.join('package-name', 'greeting')).to be_exist
      end
    end

    context "when destination not exists" do
      it "extracts package on destination" do
        extract_step.run!
        expect(destination).to be_a_directory
        expect(destination.join('greeting')).to be_exist
      end
    end

    context "with verify option" do
      it "verifies"
    end

    context "when package not exists" do
      it "-"
    end
  end
end
