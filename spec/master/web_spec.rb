require 'spec_helper'
require 'mamiya/master/web'

describe Mamiya::Master::Web do
  include Rack::Test::Methods
  let(:app) { described_class }
  let(:master) { double('master') }

  before do
    current_session.envs["rack.logger"] = Mamiya::Logger.new
    current_session.envs["mamiya.master"] = master
  end

  describe "GET /" do
    it "returns text" do
      get '/'

      expect(last_response.status).to eq 200
      expect(last_response.body).to match(/^mamiya/)
    end
  end
end
