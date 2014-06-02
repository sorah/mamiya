require 'spec_helper'
require 'stringio'
require 'tmpdir'
require 'fileutils'

require 'mamiya/logger'

describe Mamiya::Logger do
  it "can log" do
    sio = StringIO.new('', 'w')
    logger = described_class.new(outputs: [sio])
    logger.info 'hello'
    logger.close

    expect(sio.string).to match(/hello/)
  end

  context "with multiple outputs" do
    let!(:tmpdir) { Dir.mktmpdir('mamiya-logger-spec') }
    after { FileUtils.remove_entry_secure tmpdir }

    it "can log" do
      sio = StringIO.new('', 'w')
      i,o = IO.pipe
      path = File.join(tmpdir, 'test.log')

      logger = described_class.new(outputs: [sio, o, path])
      logger.info 'hello'
      logger.close

      io_out = i.read; i.close

      expect(sio.string).to match(/hello/)
      expect(io_out).to match(/hello/)
      expect(File.read(path)).to match(/hello/)
    end
  end

  describe "#[]" do
    it "can log" do
      sio = StringIO.new('', 'w')
      logger = described_class.new(outputs: [sio])
      test_logger = logger['test']
      logger.info 'hello'
      test_logger.info ''

      expect(test_logger.progname).to eq 'test'
      expect(logger.progname).to be_nil

      logger.close

      expect(sio.string).to match(/^.*hello.*$/)
      expect(sio.string).to match(/^.*test.*$/)
    end
  end

  describe "#reopen" do
    it "reopens file IOs" do
      io = double('io', path: 'foo', tty?: false, write: 0, sync: true, puts: nil)
      expect(io).to receive(:reopen).with('foo', 'a')
      expect(io).to receive(:sync=).with(true)

      logger = described_class.new(outputs: [io])

      logger.reopen
    end
  end
end
