require 'spec_helper'

require 'mamiya/agent/tasks/clean'
require 'mamiya/agent/tasks/abstract'
require 'mamiya/steps/fetch'

describe Mamiya::Agent::Tasks::Clean do
  let!(:tmpdir) { Dir.mktmpdir('mamiya-agent-tasks-clean-spec') }
  after { FileUtils.remove_entry_secure(tmpdir) if File.exist?(tmpdir) }

  let(:config) { {packages_dir: tmpdir, keep_packages: 2} }

  let(:agent) { double('agent', config: config) }
  let(:task_queue) { double('task_queue') }

  subject(:task) { described_class.new(task_queue, {}, agent: agent, raise_error: true) }

  it 'inherits abstract task' do
    expect(described_class.ancestors).to include(Mamiya::Agent::Tasks::Abstract)
  end


  describe "#execute" do
    before do
      path = Pathname.new(tmpdir)

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

      path = Pathname.new(tmpdir)
      existences = Hash[
        [
          path.join('a', 'a.tar.gz'),
          path.join('a', 'a.json'),
          path.join('a', 'b.tar.gz'),
          path.join('a', 'b.json'),
          path.join('a', 'c.tar.gz'),
          path.join('a', 'c.json'),
        ].map { |file|
          [file, file.exist?]
        }
      ]

      expect(existences).to eq(
        path.join('a', 'a.tar.gz') => false,
        path.join('a', 'a.json') => false,
        path.join('a', 'b.tar.gz') => true,
        path.join('a', 'b.json') => true,
        path.join('a', 'c.tar.gz') => true,
        path.join('a', 'c.json') => true,
      )
    end
  end
end
