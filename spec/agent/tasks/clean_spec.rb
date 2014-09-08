require 'spec_helper'

require 'mamiya/agent/tasks/clean'
require 'mamiya/agent/tasks/abstract'
require 'mamiya/steps/fetch'

describe Mamiya::Agent::Tasks::Clean do
  let!(:tmpdir) { Dir.mktmpdir('mamiya-agent-tasks-clean-spec') }
  after { FileUtils.remove_entry_secure(tmpdir) if File.exist?(tmpdir) }

  let(:packages_dir) { Pathname.new(tmpdir).join('packages').tap(&:mkdir) }
  let(:prereleases_dir) { Pathname.new(tmpdir).join('prereleases').tap(&:mkdir) }

  let(:config) do
    {packages_dir: packages_dir, keep_packages: 2,
     prereleases_dir: prereleases_dir, keep_prereleases: 2,}
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
  end
end
