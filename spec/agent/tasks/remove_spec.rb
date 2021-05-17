require 'spec_helper'

require 'mamiya/agent/tasks/remove'
require 'mamiya/configuration'

RSpec.describe Mamiya::Agent::Tasks::Remove do
  around do |example|
    Dir.mktmpdir("mamiya-agent-tasks-remove-spec") do |tmpdir|
      @tmpdir = Pathname.new(tmpdir)
      example.run
    end
  end

  let(:package_name) { 'mypkg' }
  let(:task_queue) { double('task_queue', enqueue: nil) }
  let(:agent) { double('agent', config: config) }
  let(:deploy_to) { @tmpdir.join('targets') }
  let(:release_path) { deploy_to.join('releases', package_name) }
  let(:config) do 
    Mamiya::Configuration.new.tap do |c|
      c.applications[:myapp] = {deploy_to: deploy_to}
    end
  end
  let(:job) { {'app' => 'myapp', 'pkg' => package_name} }

  let(:task) { described_class.new(task_queue, job, agent: agent, raise_error: true) }

  before do
  end

  describe "#execute" do
    context "with specified package" do
      it "removes specified package" do
        release_path.mkpath

        task.execute
        expect(release_path).to_not be_exist
      end
    end

    context "without specified package" do
      it "does nothing" do
        expect(release_path).to_not be_exist

        task.execute
        expect(release_path).to_not be_exist
      end
    end
  end
end
