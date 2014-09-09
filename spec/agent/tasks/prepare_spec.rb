require 'spec_helper'
require 'tmpdir'
require 'pathname'

require 'mamiya/agent/tasks/notifyable'
require 'mamiya/agent/tasks/prepare'

require 'mamiya/steps/extract'
require 'mamiya/steps/prepare'

describe Mamiya::Agent::Tasks::Prepare do
  let!(:tmpdir) { Pathname.new Dir.mktmpdir("mamiya-agent-tasks-prepare-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:packages_dir) { tmpdir.join('packages').tap(&:mkdir) }
  let(:prereleases_dir) { tmpdir.join('prereleases').tap(&:mkdir) }

  let(:config) do
    _pkg, _pre = packages_dir, prereleases_dir
    Mamiya::Configuration.new.evaluate! do
      set :packages_dir, _pkg
      set :prereleases_dir, _pre
    end
  end

  let(:agent) { double('agent', config: config, trigger: nil, labels: [:foo, :bar]) }
  let(:task_queue) { double('task_queue', enqueue: nil) }

  let(:extract_step) { double('extract step', run!: nil) }
  let(:prepare_step) { double('prepare step', run!: nil) }

  let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg'} }

  subject(:task) { described_class.new(task_queue, job, agent: agent, raise_error: true) }

  it 'inherits notifyable task' do
    expect(described_class.ancestors).to include(Mamiya::Agent::Tasks::Notifyable)
  end

  describe "#execute" do
    context "when package not fetched" do
      before do
        expect(Mamiya::Steps::Extract).not_to receive(:new)
        expect(Mamiya::Steps::Prepare).not_to receive(:new)
      end

      it "enqueues fetch task and finish" do
        expect(task_queue).to receive(:enqueue).with(
          :fetch, job.merge('task' => 'prepare', '_chain' => ['prepare'])
        )

        task.execute
      end

      context "with _chain-ed job" do
        let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', '_chain' => ['next']} }

        it "enqueues fetch task and finish" do
          expect(task_queue).to receive(:enqueue).with(
            :fetch, job.merge('task' => 'prepare', '_chain' => ['prepare', 'next'])
          )

          task.execute
        end
      end
    end

    context "when package fetched" do
      before do
        packages_dir.join('myapp').mkdir
        File.write packages_dir.join('myapp', 'mypkg.tar.gz'), "\n"

        allow(Mamiya::Steps::Extract).to receive(:new).with(
          package: packages_dir.join('myapp', 'mypkg.tar.gz'),
          destination: prereleases_dir.join('myapp', 'mypkg'),
          config: config,
          logger: task.logger,
        ).and_return(extract_step)

        allow(Mamiya::Steps::Prepare).to receive(:new).with(
          target: prereleases_dir.join('myapp', 'mypkg'),
          labels: [:foo, :bar],
          config: config,
          script: nil,
          logger: task.logger,
        ).and_return(prepare_step)
      end

      it "prepares extracted release" do
        expect(extract_step).to receive(:run!).ordered
        expect(prepare_step).to receive(:run!).ordered

        task.execute
      end

      context "when prepared package exists" do
        before do
          prereleases_dir.join('myapp', 'mypkg').mkpath
          File.write prereleases_dir.join('myapp', 'mypkg', '.mamiya.prepared'),
            "#{Time.now.to_i}\n"
        end

        it "does nothing" do
          expect(extract_step).not_to receive(:run!)
          expect(prepare_step).not_to receive(:run!)

          task.execute
        end
      end

      context "when extracted but non-prepared release exists" do
        before do
          prereleases_dir.join('myapp', 'mypkg').mkpath
        end

        it "removes existing release then prepare" do
          expect(extract_step).to receive(:run!).ordered do
            expect(prereleases_dir.join('myapp', 'mypkg')).not_to be_exist
          end
          expect(prepare_step).to receive(:run!).ordered

          task.execute
        end
      end
    end
  end
end
