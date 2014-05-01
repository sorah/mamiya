require 'spec_helper'
require 'tmpdir'
require 'fileutils'

require 'mamiya/storages/mock'
require 'mamiya/package'

require 'mamiya/master/web'

describe Mamiya::Master::Web do
  include Rack::Test::Methods

  let!(:tmpdir) { Dir.mktmpdir('maimya-master-web-spec') }
  after { FileUtils.remove_entry_secure(tmpdir) }

  let(:app) { described_class }

  let(:config_source) do
    {storage: {}}
  end

  let(:config) do
    double('config').tap do |c|
      allow(c).to receive(:[]) do |k|
        config_source[k]
      end

      allow(c).to receive(:storage_class).and_return(Mamiya::Storages::Mock)
    end
  end

  let(:master) { double('master', config: config) }

  let(:package) do
    File.write File.join(tmpdir, 'mypackage.tar.gz'), "\n"
    File.write File.join(tmpdir, 'mypackage.json'), "#{{meta: 'data'}.to_json}\n"
    Mamiya::Package.new(File.join(tmpdir, 'mypackage'))
  end

  before do
    described_class.set :environment, :test

    current_session.envs["rack.logger"] = Mamiya::Logger.new
    current_session.envs["mamiya.master"] = master

    Mamiya::Storages::Mock.new(application: 'myapp').push(package)
  end

  describe "GET /" do
    it "returns text" do
      get '/'

      expect(last_response.status).to eq 200
      expect(last_response.body).to match(/^mamiya/)
    end
  end

  describe "GET /packages/:application" do
    it "returns package list" do
      get '/packages/myapp'

      expect(last_response.status).to eq 200
      expect(last_response.content_type).to eq 'application/json'
      json = JSON.parse(last_response.body)
      expect(json['packages']).to eq ['mypackage']
    end

    it "returns empty list with 204 for inexistence app" do
      get '/packages/noapp'

      expect(last_response.status).to eq 404
      expect(last_response.content_type).to eq 'application/json'
      json = JSON.parse(last_response.body)
      expect(json['packages']).to eq []
    end
  end

  describe "GET /packages/:application/:package" do
    it "returns package detail" do
      get '/packages/myapp/mypackage'

      expect(last_response.status).to eq 200
      expect(last_response.content_type).to eq 'application/json'
      json = JSON.parse(last_response.body)
      expect(json['application']).to eq 'myapp'
      expect(json['name']).to eq 'mypackage'
      expect(json['meta']).to eq('meta' => 'data')
    end

    context "when not exists" do
      it "returns 404" do
        get '/packages/myapp/mypkg'

        expect(last_response.status).to eq 404
        expect(last_response.content_type).to eq 'application/json'
        expect(JSON.parse(last_response.body)).to eq({})
      end
    end
  end

  describe "POST /packages/:application/:package/distribute" do
    it "dispatchs distribute request"
  end
end
