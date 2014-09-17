require 'spec_helper'

require 'mamiya/agent/tasks/clean'
require 'mamiya/agent/tasks/abstract'
require 'mamiya/steps/fetch'
require 'mamiya/configuration'

describe Mamiya::Agent::Tasks::Clean do
  let!(:tmpdir) { Dir.mktmpdir('mamiya-agent-tasks-clean-spec') }
  after { FileUtils.remove_entry_secure(tmpdir) if File.exist?(tmpdir) }

  let(:packages_dir) { Pathname.new(tmpdir).join('packages').tap(&:mkdir) }
  let(:prereleases_dir) { Pathname.new(tmpdir).join('prereleases').tap(&:mkdir) }
  
  let(:deploy_to_a) {  Pathname.new(tmpdir).join('app_a').tap(&:mkdir)  }
  let(:deploy_to_b) {  Pathname.new(tmpdir).join('app_b').tap(&:mkdir)  }

  let(:config) do
    Mamiya::Configuration.new.tap do |c|
      c.set :packages_dir, packages_dir
      c.set :prereleases_dir, prereleases_dir 
      c.set :keep_packages, 2
      c.set :keep_prereleases, 2
      c.set :keep_releases, 2

      c.applications[:app_a] = {deploy_to: deploy_to_a}
      c.applications[:app_b] = {deploy_to: deploy_to_b}
    end
  end

  let(:agent) { double('agent', config: config) }
  let(:task_queue) { double('task_queue') }


  subject(:task) { described_class.new(task_queue, {}, agent: agent, raise_error: true) }

  it 'inherits abstract task' do
    expect(described_class.ancestors).to include(Mamiya::Agent::Tasks::Abstract)
  end


  describe "#execute" do
    describe "packages" do
      before do
        path = packages_dir

        path.join('a').mkdir
        File.write path.join('a', "a.tar.gz"), "\n"
        File.write path.join('a', "a.json"), "\n"
        File.write path.join('a', "b.json"), "\n"
        File.write path.join('a', "b.tar.gz"), "\n"
        File.write path.join('a', "c.json"), "\n"
        File.write path.join('a', "c.tar.gz"), "\n"
        path.join('b').mkdir
        File.write path.join('b', "a.tar.gz"), "\n"
        File.write path.join('b', "a.json"), "\n"

        path.join('c').mkdir
        File.write path.join('c', "a.tar.gz"), "\n"
        File.write path.join('c', "b.json"), "\n"
      end

      it "cleans up" do
        expect(agent).to receive(:trigger).with('pkg', action: 'remove', application: 'a', package: 'a', coalesce: false)

        task.execute

        existences = Hash[
          [
            packages_dir.join('a', 'a.tar.gz'),
            packages_dir.join('a', 'a.json'),
            packages_dir.join('a', 'b.tar.gz'),
            packages_dir.join('a', 'b.json'),
            packages_dir.join('a', 'c.tar.gz'),
            packages_dir.join('a', 'c.json'),
          ].map { |file|
            [file, file.exist?]
          }
        ]

        expect(existences).to eq(
          packages_dir.join('a', 'a.tar.gz') => false,
          packages_dir.join('a', 'a.json') => false,
          packages_dir.join('a', 'b.tar.gz') => true,
          packages_dir.join('a', 'b.json') => true,
          packages_dir.join('a', 'c.tar.gz') => true,
          packages_dir.join('a', 'c.json') => true,
        )
      end
    end

    describe "prereleases_dir" do
      before do
        path = prereleases_dir

        # TODO: XXX: this may remove ongoing preparing somewhat
        path.join('a').mkdir
        path.join('a', '1').mkdir
        path.join('a', '2').mkdir
        path.join('a', '3').mkdir
        path.join('b').mkdir
        path.join('b', '1').mkdir
        path.join('b', '2').mkdir
      end

      it "cleans up" do
        expect(agent).to receive(:trigger).with('prerelease', action: 'remove', app: 'a', pkg: '1', coalesce: false)

        task.execute

        existences = Hash[
          [
            prereleases_dir.join('a', '1'),
            prereleases_dir.join('a', '2'),
            prereleases_dir.join('a', '3'),
            prereleases_dir.join('b', '1'),
            prereleases_dir.join('b', '2'),
          ].map { |file|
            [file, file.exist?]
          }
        ]

        expect(existences).to eq(
          prereleases_dir.join('a', '1') => false,
          prereleases_dir.join('a', '2') => true,
          prereleases_dir.join('a', '3') => true,
          prereleases_dir.join('b', '1') => true,
          prereleases_dir.join('b', '2') => true,
        )
      end
    end

    describe "releases_dir" do
      before do
        # TODO: XXX: this may remove ongoing preparing somewhat
        deploy_to_a.join('releases').tap do |path|
          path.mkdir
          path.join('1').mkdir
          path.join('2').mkdir
          path.join('3').mkdir
        end

        deploy_to_b.join('releases').tap do |path|
          path.mkdir
          path.join('1').mkdir
          path.join('2').mkdir
        end
      end

      it "cleans up" do
        expect(agent).to receive(:trigger).with('release', action: 'remove', app: :app_a, pkg: '1', coalesce: false)

        task.execute

        existences = Hash[
          [
            deploy_to_a.join('releases', '1'),
            deploy_to_a.join('releases', '2'),
            deploy_to_a.join('releases', '3'),
            deploy_to_b.join('releases', '1'),
            deploy_to_b.join('releases', '2'),
          ].map { |file|
            [file, file.exist?]
          }
        ]

        expect(existences).to eq(
            deploy_to_a.join('releases', '1') => false,
            deploy_to_a.join('releases', '2') => true,
            deploy_to_a.join('releases', '3') => true,
            deploy_to_b.join('releases', '1') => true,
            deploy_to_b.join('releases', '2') => true,
        )
      end

      context "with current release" do
        before do
          deploy_to_a.join('current').make_symlink deploy_to_a.join('releases', '1')
        end

        it "cleans up" do
          task.execute

          existences = Hash[
            [
              deploy_to_a.join('releases', '1'),
              deploy_to_a.join('releases', '2'),
              deploy_to_a.join('releases', '3'),
              deploy_to_b.join('releases', '1'),
              deploy_to_b.join('releases', '2'),
            ].map { |file|
              [file, file.exist?]
            }
          ]

          expect(existences).to eq(
              deploy_to_a.join('releases', '1') => true,
              deploy_to_a.join('releases', '2') => true,
              deploy_to_a.join('releases', '3') => true,
              deploy_to_b.join('releases', '1') => true,
              deploy_to_b.join('releases', '2') => true,
          )
        end
      end
    end
  end
end
