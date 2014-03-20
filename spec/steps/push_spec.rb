require 'spec_helper'
require 'tmpdir'
require 'pathname'
require 'fileutils'

require 'mamiya/package'
require 'mamiya/storages/mock'

require 'mamiya/steps/push'

describe Mamiya::Steps::Push do
  let!(:tmpdir) { Dir.mktmpdir("mamiya-steps-build-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:package_dir) { Pathname.new(tmpdir).join('pkg').tap(&:mkdir) }

  let(:target_package) { package_dir.join('test.tar.gz').to_s }
  let(:script) do
    double('script',
      application: 'myapp',
    )
  end

  let(:config_source) do
    {
      storage: {
      }
    }
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
    {package: target_package}
  end

  subject(:push_step) { described_class.new(script: script, config: config, **options) }

  describe "#run!" do
    let(:package_application) do
      # to confirm Push step uses package's application name
      'app'
    end

    before do
      File.write target_package, "\n"
      File.write target_package.gsub(/\.tar\.gz$/,'.json'), "{}\n"

      allow_any_instance_of(Mamiya::Package).to receive(:application).and_return(package_application)
    end

    it "pushes package to storage" do
      push_step.run!
      expect(Mamiya::Storages::Mock.storage['app']['test']).not_to be_nil
    end

    context "with application option" do
      let(:options) { {package: target_package, application: 'newapp'} }

      it "pushes package to storage for given application name" do
        push_step.run!
        expect(Mamiya::Storages::Mock.storage['newapp']['test']).not_to be_nil
      end
    end
  end
end
