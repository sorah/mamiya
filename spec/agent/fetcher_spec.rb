require 'spec_helper'
require 'pathname'
require 'tmpdir'
require 'fileutils'

require 'mamiya/agent/fetcher'
require 'mamiya/steps/fetch'


describe Mamiya::Agent::Fetcher do
  let!(:tmpdir) { Dir.mktmpdir('mamiya-agent-fetcher-spec') }
  after { FileUtils.remove_entry_secure(tmpdir) if File.exist?(tmpdir) }

  let(:config) do
    {packages_dir: tmpdir, keep_packages: 2}
  end

  subject(:fetcher) { described_class.new(config) }

  describe "lifecycle" do
    it "can start and stop" do
      expect(fetcher.worker_thread).to be_nil
      expect(fetcher).not_to be_running

      fetcher.start!

      expect(fetcher).to be_running
      expect(fetcher.worker_thread).to be_a(Thread)
      expect(fetcher.worker_thread).to be_alive
      th = fetcher.worker_thread

      fetcher.stop!

      20.times { break unless th.alive?; sleep 0.1 }
      expect(th).not_to be_alive

      expect(fetcher.worker_thread).to be_nil
      expect(fetcher).not_to be_running
    end

    it "can graceful stop"
  end

  describe "#cleanup" do
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
      called = []
      fetcher.cleanup_hook = proc { |a,b| called << [a,b] }

      fetcher.cleanup

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

      expect(called).to eq([['a', 'a']])
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

  describe "#pending_jobs" do
    before do
      step = double('fetch-step')
      allow(step).to receive(:run!)
      allow(Mamiya::Steps::Fetch).to receive(:new).with(
        application: 'myapp',
        package: 'package',
        destination: File.join(tmpdir, 'myapp'),
        config: config,
      ).and_return(step)
    end

    it "shows remaining jobs" do
      fetcher.start!; fetcher.worker_thread.kill

      expect {
        fetcher.enqueue('myapp', 'package')
        fetcher.stop!(:graceful)
      }.to change { fetcher.pending_jobs } \
        .from([]).to([['myapp', 'package', nil, nil]])

      fetcher.start!; fetcher.stop!(:graceful)

      expect(fetcher.pending_jobs).to be_empty
    end
  end

  describe "mainloop" do
    before do
      allow(step).to receive(:run!)
      allow(Mamiya::Steps::Fetch).to receive(:new).with(
        application: 'myapp',
        package: 'package',
        destination: File.join(tmpdir, 'myapp'),
        config: config,
      ).and_return(step)

      fetcher.start!
    end

    let(:step) { double('fetch-step') }

    it "starts fetch step for each order" do
      flag = false

      expect(step).to receive(:run!) do
        flag = true
      end

      fetcher.enqueue('myapp', 'package')
      fetcher.stop!(:graceful)
    end

    it "calls callback" do
      received = true

      fetcher.enqueue('myapp', 'package') do |succeeded|
        expect(fetcher.working?).to be_false
        received = succeeded
      end

      fetcher.stop!(:graceful)

      expect(received).to be_nil
    end

    it "calls cleanup" do
      expect(fetcher).to receive(:cleanup)
      fetcher.enqueue('myapp', 'package')
      fetcher.stop!(:graceful)
    end

    it "claims itself as working" do
      expect(fetcher.working?).to be_false
      expect(fetcher.current_job).to be_nil

      received = false
      fetcher.enqueue 'myapp', 'package', before: proc { |error|
        expect(fetcher.working?).to be_true
        expect(fetcher.current_job).to eq %w(myapp package)
        received = true
      }

      fetcher.stop!(:graceful)
      expect(received).to be_true
      expect(fetcher.working?).to be_false
      expect(fetcher.current_job).to be_nil
    end

    context "with config.fetch_sleep" do
      it "calls sleep" do
        config[:fetch_sleep] = 1
        expect(fetcher).to receive(:sleep)
        fetcher.enqueue 'myapp', 'package'
        fetcher.stop!(:graceful)
      end
    end

    context "with before hook" do
      it "calls callback" do
        run = false
        received = false

        allow(step).to receive(:run!) do
          run = true
        end

        fetcher.enqueue('myapp', 'package', before: proc {
          received = true
          expect(run).to be_false
        })
        fetcher.stop!(:graceful)

        expect(received).to be_true
      end
    end

    context "when fetch step raised error" do
      let(:exception) { Exception.new("he he...") }

      before do
        allow(step).to receive(:run!).and_raise(exception)
      end

      it "calls callback with error" do
        received = nil

        fetcher.enqueue('myapp', 'package') do |error|
          received = error
        end

        fetcher.stop!(:graceful)

        expect(received).to eq exception
      end
    end

    after do
      fetcher.stop!
    end
  end
end
