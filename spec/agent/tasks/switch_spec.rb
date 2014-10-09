require 'spec_helper'
require 'tmpdir'
require 'pathname'

require 'mamiya/agent/tasks/switch'

require 'mamiya/steps/switch'

describe Mamiya::Agent::Tasks::Switch do
  let!(:tmpdir) { Pathname.new Dir.mktmpdir("mamiya-agent-tasks-switch-spec") }
  after { FileUtils.remove_entry_secure tmpdir }

  let(:deploy_to) { tmpdir.join('deploy_to').tap(&:mkpath) }
  let(:packages_dir) { tmpdir.join('packages').tap(&:mkpath) }
  let(:packages_app_dir) { tmpdir.join('packages', 'myapp').tap(&:mkpath) }
  let(:prereleases_dir) { tmpdir.join('prereleases').tap(&:mkpath) }
  let(:prereleases_app_dir) { tmpdir.join('prereleases', 'myapp').tap(&:mkpath) }


  let(:config) do
    _pkg, _pre, _dto = packages_dir, prereleases_dir, deploy_to
    Mamiya::Configuration.new.evaluate! do
      set :packages_dir, _pkg
      set :prereleases_dir, _pre
      applications[:myapp] = {deploy_to: _dto}
    end
  end

  let(:agent) { double('agent', config: config, trigger: nil, labels: [:foo, :bar]) }
  let(:task_queue) { double('task_queue', enqueue: nil) }

  let(:switch_step) { double('switch step', run!: nil) }

  let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg'} }

  subject(:task) { described_class.new(task_queue, job, agent: agent, raise_error: true) }

  it 'inherits notifyable task' do
    expect(described_class.ancestors).to include(Mamiya::Agent::Tasks::Notifyable)
  end

  describe "#execute" do
    context "when package not fetched and not prepared" do
      before do
        expect(Mamiya::Steps::Switch).not_to receive(:new)
      end

      it "enqueues fetch task and finish" do
        expect(task_queue).to receive(:enqueue).with(
          :fetch, job.merge('task' => 'switch', '_chain' => ['prepare', 'switch'])
        )

        task.execute
      end

      context "with _chain-ed job" do
        let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', '_chain' => ['next']} }

        it "enqueues prepare task and finish" do
          expect(task_queue).to receive(:enqueue).with(
            :fetch, job.merge('task' => 'switch', '_chain' => ['prepare', 'switch', 'next'])
          )

          task.execute
        end
      end
    end

    context "when package fetched but not prepared" do
      before do
        File.write packages_app_dir.join('mypkg.tar.gz'), "\n"
        File.write packages_app_dir.join('mypkg.json'), "{}\n"
        expect(Mamiya::Steps::Switch).not_to receive(:new)
      end

      it "enqueues prepare task and finish" do
        expect(task_queue).to receive(:enqueue).with(
          :prepare, job.merge('task' => 'switch', '_chain' => ['switch'])
        )

        task.execute
      end

      context "with _chain-ed job" do
        let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', '_chain' => ['next']} }

        it "enqueues prepare task and finish" do
          expect(task_queue).to receive(:enqueue).with(
            :prepare, job.merge('task' => 'switch', '_chain' => ['switch', 'next'])
          )

          task.execute
        end
      end
    end

    context "when package fetched but incompletely prepared" do
      before do
        File.write packages_app_dir.join('mypkg.tar.gz'), "\n"
        File.write packages_app_dir.join('mypkg.json'), "{}\n"

        # no .mamiya.prepare
        prerelease = prereleases_app_dir.join('mypkg').tap(&:mkpath)
        File.write prerelease.join('hello'), "hola\n"
      end

      context "without task.incomplete" do
        before do
          expect(Mamiya::Steps::Switch).not_to receive(:new)
        end

        it "enqueues prepare task and finish" do
          expect(task_queue).to receive(:enqueue).with(
            :prepare, job.merge('task' => 'switch', '_chain' => ['switch'])
          )

          task.execute
        end

        context "with _chain-ed job" do
          let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', '_chain' => ['next']} }

          it "enqueues prepare task and finish" do
            expect(task_queue).to receive(:enqueue).with(
              :prepare, job.merge('task' => 'switch', '_chain' => ['switch', 'next'])
            )

            task.execute
          end
        end
      end

      context "with task.incomplete=true" do
        let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', 'incomplete' => true} }

        before do
          allow(Mamiya::Steps::Switch).to receive(:new).with(
            target: deploy_to.join('releases', 'mypkg'),
            labels: [:foo, :bar],
            no_release: false,
            do_release: false,
            config: config,
            logger: task.logger,
          ).and_return(switch_step)
        end

        it "calls switch step" do
          expect(switch_step).to receive(:run!) do
            expect(deploy_to.join('releases', 'mypkg', 'hello')).to be_exist
          end
          task.execute
        end
      end
    end

    context "when package prepared" do
      before do
        File.write packages_app_dir.join('mypkg.tar.gz'), "\n"
        File.write packages_app_dir.join('mypkg.json'), "{}\n"

        prerelease = prereleases_app_dir.join('mypkg').tap(&:mkpath)
        File.write prerelease.join('hello'), "hola\n"
        File.write prerelease.join('.mamiya.prepared'), "#{Time.now.to_i}\n"

        allow(Mamiya::Steps::Switch).to receive(:new).with(
          target: deploy_to.join('releases', 'mypkg'),
          labels: [:foo, :bar],
          no_release: false,
          do_release: false,
          config: config,
          logger: task.logger,
        ).and_return(switch_step)
      end

      it "copies prerelease to releases_dir" do
        expect {
          task.execute
        }.to change {
          deploy_to.join('releases', 'mypkg', 'hello').exist? &&
          deploy_to.join('releases', 'mypkg', 'hello').read
        }.from(false).to "hola\n"
      end

      it "calls switch step" do
        expect(switch_step).to receive(:run!) do
          expect(deploy_to.join('releases', 'mypkg', 'hello')).to be_exist
        end
        task.execute
      end

      context "when prepared release exists in releases_dir" do
        before do
          release = deploy_to.join('releases', 'mypkg').tap(&:mkpath)
          File.write release.join('hehe'), ":)\n"
          File.write release.join('.mamiya.prepared'), "#{Time.now.to_i}\n"
        end

        it "re-uses existing release" do
          task.execute
          expect(deploy_to.join('releases', 'mypkg', 'hehe').read).to eq ":)\n"
        end
      end

      context "when non-prepared release exists in releases_dir" do
        before do
          release = deploy_to.join('releases', 'mypkg').tap(&:mkpath)
          File.write release.join('hehe'), ":)\n"
        end

        it "re-uses existing release" do
          task.execute
          expect(deploy_to.join('releases', 'mypkg', 'hehe')).not_to be_exist
          expect(deploy_to.join('releases', 'mypkg', 'hello')).to be_exist
        end
      end

      context "with no_release" do
        let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', 'no_release' => true} }

        it "calls switch step with no_release" do
          expect(Mamiya::Steps::Switch).to receive(:new).with(
            target: deploy_to.join('releases', 'mypkg'),
            labels: [:foo, :bar],
            no_release: true,
            do_release: false,
            config: config,
            logger: task.logger,
          ).and_return(switch_step)

          expect(switch_step).to receive(:run!)

          task.execute
        end
      end

      context "with do_release" do
        let(:job) { {'app' => 'myapp', 'pkg' => 'mypkg', 'do_release' => true} }

        it "calls switch step with no_release" do
          expect(Mamiya::Steps::Switch).to receive(:new).with(
            target: deploy_to.join('releases', 'mypkg'),
            labels: [:foo, :bar],
            no_release: false,
            do_release: true,
            config: config,
            logger: task.logger,
          ).and_return(switch_step)

          expect(switch_step).to receive(:run!)

          task.execute
        end
      end
    end
  end
end
