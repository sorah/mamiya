require 'mamiya/util/label_matcher'
require 'thread'

module Mamiya
  class DSL
    class TaskNotDefinedError < Exception; end
    class HelperNotFound < Exception; end

    ##
    # Creates new DSL environment.
    def initialize
      @variables = {}
      @tasks = {}
      @hooks = {}
      @eval_lock = Mutex.new
      @use_lock = Mutex.new
    end

    attr_reader :hooks, :tasks

    ##
    # Returns Hash of default setting variables.
    def self.defaults
      @defaults ||= {}
    end

    def self.define_variable_accessor(name) # :nodoc:
      k = name.to_sym
      return if self.instance_methods.include?(k)

      define_method(k) { self[k] }
    end

    ##
    # Sets default value +value+ for variable name +key+.
    # Values set by this method will available for all instances of same class.
    def self.set_default(key, value)
      k = key.to_sym
      defaults[k] = value
      self.define_variable_accessor(k)
    end

    ##
    # Add hook point with name +name+.
    # This defines method with same name in class to call and define hooks.
    def self.add_hook(name, attributes={})
      define_method(name) do |*args, &block|
        @hooks[name] ||= []

        if block
          hook_name = args.shift if args.first.kind_of?(String)
          options = args.pop if args.last.kind_of?(Hash)

          hook = {block: block, options: options || {}, name: hook_name}
          case args.first
          when :overwrite
            @hooks[name] = [hook]
          when :prepend
            @hooks[name][0,0] = [hook]
          else
            @hooks[name] << hook
          end

        else
          matcher = Mamiya::Util::LabelMatcher::Simple.new(args)
          Proc.new { |*args|
            filtered_hooks = @hooks[name].reject { |hook|
              options = hook[:options]

              (options[:only]   && !matcher.match?(*options[:only]  )) ||
              (options[:except] &&  matcher.match?(*options[:except]))
            }

            if attributes[:chain]
              init = args.shift
              filtered_hooks.inject(init) do |result, hook|
                hook[:block].call(result, *args)
              end
            else
              filtered_hooks.each do |hook|
                hook[:block].call *args
              end
            end
          }
        end
      end
    end

    ##
    # :call-seq:
    #   evaluate!(string [, filename [, lineno]])
    #   evaluate! { block }
    #
    # Evaluates given string or block in DSL environment.
    def evaluate!(str = nil, filename = nil, lineno = nil, &block)
      @eval_lock.synchronize {
        begin
          if block_given?
            self.instance_eval(&block)
          elsif str
            @file = filename if filename

            if str && filename && lineno
              self.instance_eval(str, filename, lineno)
            elsif str && filename
              self.instance_eval(str, filename)
            elsif str
              self.instance_eval(str)
            end
          end
        ensure
          @file = nil
        end
      }
      self
    end

    ##
    # Evaluates specified file +file+ in DSL environment.
    def load!(file)
      evaluate! File.read(file), file, 1
    end

    ##
    # (DSL) Find file using +name+ from current +load_path+ then load.
    # +options+ will be available as variable +options+ in loaded file.
    def use(name, options={})
      helper_file = find_helper_file(name)
      raise HelperNotFound unless helper_file

      @use_lock.lock unless @use_lock.owned? # to avoid lock recursively

      @_options = options
      self.instance_eval File.read(helper_file).prepend("options = @_options; @_options = nil;\n"), helper_file, 1

    ensure
      @_options = nil
      @use_lock.unlock if @use_lock.owned?
    end

    ##
    # (DSL) Set value +value+ for variable named +key+.
    def set(key, value)
      k = key.to_sym
      self.class.define_variable_accessor(key) unless self.methods.include?(k)
      @variables[k] = value
    end

    ##
    # (DSL) Set value +value+ for variable named +key+ unless value is present for the variable.
    def set_default(key, value)
      k = key.to_sym
      return @variables[k] if @variables.key?(k)
      set(k, value)
    end

    ##
    # (DSL) Retrieve value for key +key+. Value can be set using DSL#set .
    def [](key)
      @variables[key] || self.class.defaults[key]
    end

    ##
    # (DSL) Define task named +name+ with given block.
    def task(name, &block)
      @tasks[name] = block
    end

    ##
    # (DSL) Invoke task named +name+.
    def invoke(name)
      raise TaskNotDefinedError unless @tasks[name]
      self.instance_eval &@tasks[name]
    end

    ##
    # Returns current load path used by +use+ method.
    def load_path
      (@variables[:load_path] ||= []) +
        [
          "#{__dir__}/helpers",
          *(@file ? ["#{File.dirname(@file)}/helpers"] : [])
        ]
    end

    private

    def find_helper_file(name) # :nodoc:
      load_path.find do |_| # Using find to return nil when not found
        path = File.join(_, "#{name}.rb")
        break path if File.exists?(path)
      end
    end

    # TODO: hook call context methods
    #https://gist.github.com/sorah/9263951
  end
end
