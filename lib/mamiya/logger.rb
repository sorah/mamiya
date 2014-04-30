require 'logger'
require 'forwardable'
require 'thread'
require 'term/ansicolor'
require 'time'

module Mamiya
  class Logger
    include ::Logger::Severity
    extend Forwardable

    def self.defaults
      return @defaults if @defaults
      if ENV["MAMIYA_LOG_LEVEL"]
        level = ::Logger::Severity.const_get(ENV["MAMIYA_LOG_LEVEL"].upcase) rescue INFO
      else
        level = INFO
      end
      @defaults = {color: nil, outputs: [STDOUT], level: level}
    end

    def initialize(color: self.class.defaults[:color], outputs: self.class.defaults[:outputs], level: self.class.defaults[:level])
      @logdev = LogDev.new(outputs)
      @logger = ::Logger.new(@logdev)
      @logger.level = level
      @logger.formatter = method(:format)

      @color = color.nil? ? @logdev.tty? : color
    end

    attr_accessor :color
    def_delegators :@logger,
      :<<, :add, :log,
      :fatal, :error, :warn, :info, :debug,
      :fatal?, :error?, :warn?, :info?, :debug?,
      :level, :level=, :progname, :progname=,
      :close

    def add_output(*outputs)
      @logdev.add(*outputs)
    end

    def remove_output(*outputs)
      @logdev.remove(*outputs)
    end

    def with_additional_file(*outputs)
      @logdev.add_output(*outputs)

      yield

    ensure
      @logdev.remove_output(*outputs)
    end

    def [](progname)
      self.dup.tap do |new_logger|
        new_logger.instance_eval do
          @logger = @logger.dup
          @logger.progname = progname
        end
      end
    end

    private

    def format(severity, time, progname, msg)
      rseverity = " #{severity.rjust(5)} "
      if @color
        colored_severity = case severity
          when 'ANY'.freeze
            rseverity
          when 'DEBUG'.freeze
            Term::ANSIColor.on_black(rseverity)
          when 'INFO'.freeze
            Term::ANSIColor.on_blue(rseverity)
          when 'WARN'.freeze
            Term::ANSIColor.on_yellow(Term::ANSIColor.black(rseverity))
          when 'ERROR'.freeze
            Term::ANSIColor.on_magenta(rseverity)
          when 'FATAL'.freeze
            Term::ANSIColor.on_red(Term::ANSIColor.white(Term::ANSIColor.bold(rseverity)))
          else
            rseverity
          end
      else
        colored_severity = "#{rseverity}|"
      end

      msg = "#{(progname && "[#{progname}] ")}#{msg}"
      if @color
        colored_msg = case severity
          when 'DEBUG'.freeze
            Term::ANSIColor.bright_black(msg)
          when 'FATAL'.freeze
            Term::ANSIColor.bold(msg)
          else
            msg
          end
      else
        colored_msg = msg
      end

      formatted_time = time.strftime('%m/%d %H:%M:%S')
      colored_time = @color ? Term::ANSIColor.bright_black(formatted_time) : formatted_time

      "#{colored_time} " \
      "#{colored_severity} " \
      "#{colored_msg}" \
      "\n"
    end

    class LogDev
      def initialize(outputs)
        @outputs = normalize_outputs(outputs)
        @mutex = Mutex.new
      end

      def tty?
        @outputs.all?(&:tty?)
      end

      def write(*args)
        @outputs.each do |output|
          output.write(*args) unless output.respond_to?(:closed?) && output.closed?
        end
        self
      end

      def close
        @outputs.each do |output|
          output.close unless output.respond_to?(:closed?) && output.closed?
        end
        self
      end

      def add(*outputs)
        @mutex.synchronize do
          @outputs.push(*normalize_outputs(outputs))
        end
        self
      end

      def remove(*removing_outputs)
        @mutex.synchronize do
          removing_outputs.each do |removing|
            case removing
            when File
              @outputs.reject! { |out| out.kind_of?(File) && out.path == removing.path }
            when IO
              @outputs.reject! { |out| out.kind_of?(IO) && out.fileno == removing.fileno }
            when String
              @outputs.reject! { |out| out.kind_of?(File) && out.path == removing }
            when Integer
              @outputs.reject! { |out| out.kind_of?(IO) && out.fileno == removing }
            else
              @outputs.reject! { |out| out == removing }
            end
          end
        end
        self
      end

      private

      def normalize_outputs(ary)
        ary.map do |out|
          case
          when out.respond_to?(:write)
            out
          when out.kind_of?(String)
            File.open(out, 'a')
          end
        end
      end
    end
  end
end
