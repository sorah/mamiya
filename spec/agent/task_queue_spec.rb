require 'spec_helper'
require 'thread'
require 'mamiya/agent/tasks/abstract'
require 'mamiya/agent/task_queue'

describe Mamiya::Agent::TaskQueue do
  let(:agent) do
    double('agent')
  end

  let(:task_class_root) do
    Class.new(Mamiya::Agent::Tasks::Abstract) do
      def self.runs
        @runs ||= []
      end

      def self.locks
        @locks ||= {}
      end

      def self.locks_lock
        @locks_lock ||= Mutex.new
      end

      def execute
        self.class.runs << task.dup
        if task['wait']
          begin
            queue = Queue.new
            self.class.locks_lock.synchronize do
              self.class.locks[self.task] = queue
            end
            queue.pop
          ensure
            self.class.locks_lock.synchronize do
              self.class.locks.delete self.task
            end
          end
        end
      end
    end
  end


  let(:task_class_a) do
    Class.new(task_class_root) do
      def self.identifier
        'a'
      end
    end
  end

  let(:task_class_b) do
    Class.new(task_class_root) do
      def self.identifier
        'b'
      end
    end
  end

  subject(:queue) do
    described_class.new(agent, task_classes: [task_class_a, task_class_b])
  end

  describe "lifecycle (#start!, #stop!)" do
    it "can start and stop" do
      expect(queue).not_to be_running
      expect(queue.worker_threads).to be_nil

      queue.start!

      expect(queue).to be_running

      expect(queue.worker_threads).to be_a_kind_of(Hash)
      expect(queue.worker_threads.values.all? { |v| v.kind_of?(Thread) }).to be_true
      expect(queue.worker_threads.values.all? { |v| v.alive? }).to be_true
      threads = queue.worker_threads.dup

      queue.stop!

      expect(queue).not_to be_running
      expect(queue.worker_threads).to be_nil
      expect(threads.each_value.all? { |v| !v.alive? }).to be_true
    end

    it "can stop gracefully"
  end

  describe "work loop (#enqueue, #running?, #working, #status)" do
    after do
      queue.stop! if queue.running?
    end

    it "run enqueued task" do
      queue.start!

      queue.enqueue(:a, 'foo' => '1')
      queue.enqueue(:a, 'foo' => '2')
      100.times { break if task_class_a.runs.size == 2; sleep 0.01 }

      expect(task_class_a.runs.size).to eq 2
      expect(task_class_a.runs[0]['foo']).to eq '1'
      expect(task_class_a.runs[1]['foo']).to eq '2'
    end

    describe "(task with _labels)" do
      it "runs on matched agent" do
        queue.start!
        expect(agent).to receive(:match?).with(['foo', 'bar']).and_return(true)

        queue.enqueue(:a, 'foo' => '1', '_labels' => ['foo', 'bar'])

        100.times { break if task_class_a.runs.size == 1; sleep 0.01 }
        expect(task_class_a.runs.size).to eq 1
        expect(task_class_a.runs[0]['foo']).to eq '1'
      end

      it "doesn't run on not matched agent" do
        queue.start!
        expect(agent).to receive(:match?).with(['foo', 'bar']).and_return(false)

        queue.enqueue(:a, 'foo' => '1', '_labels' => ['foo', 'bar'])
        queue.enqueue(:a, 'foo' => '2')

        100.times { break if task_class_a.runs.size == 1; sleep 0.01 }
        expect(task_class_a.runs.size).to eq 1
        expect(task_class_a.runs[0]['foo']).to eq '2'
      end

      it "removes _labels from task on run" do
        queue.start!
        expect(agent).to receive(:match?).with(['foo', 'bar']).and_return(true)

        queue.enqueue(:a, 'foo' => '1', '_labels' => ['foo', 'bar'])

        100.times { break if task_class_a.runs.size == 1; sleep 0.01 }
        expect(task_class_a.runs.size).to eq 1
        expect(task_class_a.runs[0].key?('_labels')).to be_false
      end
    end

    describe "#working?" do
      it "returns true if there're any working tasks" do
        queue.start!

        expect(queue).not_to be_working

        queue.enqueue(:a, 'wait' => true, 'id' => 1)
        100.times { break unless task_class_a.locks.empty?; sleep 0.01 }
        expect(task_class_a.locks).not_to be_empty
        expect(queue).to be_working

        task_class_a.locks.values.last << true

        100.times { break unless queue.working?; sleep 0.01 }
        expect(queue).not_to be_working
      end
    end


    describe "#status" do
      it "shows status" do
        queue.start!

        expect(queue.status[:a][:working]).to be_nil
        expect(queue.status[:a][:queue]).to be_a_kind_of(Array)
        expect(queue.status[:a][:queue]).to be_empty

        queue.enqueue(:a, 'wait' => true, 'id' => 1)

        100.times { break unless task_class_a.locks.empty?; sleep 0.01 }
        expect(task_class_a.locks).not_to be_empty
        expect(queue.status[:a][:working]).to eq('wait' => true, 'id' => 1)

        queue.enqueue(:a, 'id' => 2)
        100.times { break unless queue.status[:a][:queue].empty?; sleep 0.01 }
        expect(queue.status[:a][:queue].size).to eq 1
        expect(queue.status[:a][:queue].first).to eq('id' => 2)

        task_class_a.locks.values.last << true

        100.times { break unless queue.status[:a][:working]; sleep 0.01 }
        expect(queue.status[:a][:working]).to be_nil
        expect(queue.status[:a][:queue]).to be_empty
      end
    end

    context "with multiple task classes" do
      it "run enqueued task" do
        queue.start!

        queue.enqueue(:a, 'foo' => '1')
        queue.enqueue(:b, 'foo' => '2')
        100.times { break if task_class_a.runs.size == 1 && task_class_b.runs.size == 1; sleep 0.01 }

        expect(task_class_a.runs.size).to eq 1
        expect(task_class_b.runs.size).to eq 1
        expect(task_class_a.runs[0]['foo']).to eq '1'
        expect(task_class_b.runs[0]['foo']).to eq '2'
      end

      it "run enqueued task parallel" do
        queue.start!

        queue.enqueue(:a, 'foo' => '1', 'wait' => true)
        queue.enqueue(:b, 'foo' => '2', 'wait' => true)
        100.times { break if task_class_a.locks.size == 1 && task_class_b.locks.size == 1; sleep 0.01 }

        expect(task_class_a.locks.size).to eq 1
        expect(task_class_b.locks.size).to eq 1
        task_class_a.locks.each_value.first << true
        task_class_b.locks.each_value.first << true

        expect(task_class_a.runs.size).to eq 1
        expect(task_class_b.runs.size).to eq 1
        expect(task_class_a.runs[0]['foo']).to eq '1'
        expect(task_class_b.runs[0]['foo']).to eq '2'
      end

      describe "#status" do
        it "shows status for each task class" do
          queue.start!

          expect(queue.status[:a][:working]).to be_nil
          expect(queue.status[:a][:queue]).to be_a_kind_of(Array)
          expect(queue.status[:a][:queue]).to be_empty

          expect(queue.status[:b][:working]).to be_nil
          expect(queue.status[:b][:queue]).to be_a_kind_of(Array)
          expect(queue.status[:b][:queue]).to be_empty

          queue.enqueue(:a, 'wait' => true, 'id' => 1)
          queue.enqueue(:b, 'wait' => true, 'id' => 2)

          100.times { break if !task_class_a.locks.empty? && !task_class_a.locks.empty?; sleep 0.01 }
          expect(task_class_a.locks).not_to be_empty
          expect(task_class_b.locks).not_to be_empty

          expect(queue.status[:a][:working]).to eq('wait' => true, 'id' => 1)
          expect(queue.status[:b][:working]).to eq('wait' => true, 'id' => 2)

          queue.enqueue(:a, 'id' => 3)
          queue.enqueue(:b, 'id' => 4)
          100.times { break if !queue.status[:a][:queue].empty? && !queue.status[:b][:queue].empty?; sleep 0.01 }
          expect(queue.status[:a][:queue].size).to eq 1
          expect(queue.status[:a][:queue].first).to eq('id' => 3)
          expect(queue.status[:b][:queue].size).to eq 1
          expect(queue.status[:b][:queue].first).to eq('id' => 4)

          task_class_a.locks.values.last << true
          task_class_b.locks.values.last << true

          100.times { break if !queue.status[:a][:working] && !queue.status[:b][:working]; sleep 0.01 }
          expect(queue.status[:a][:working]).to be_nil
          expect(queue.status[:a][:queue]).to be_empty
          expect(queue.status[:b][:working]).to be_nil
          expect(queue.status[:b][:queue]).to be_empty

        end
      end

      describe "#working?" do
        it "returns true if there're any working tasks" do
          queue.start!

          expect(queue).not_to be_working

          queue.enqueue(:a, 'wait' => true, 'id' => 1)
          100.times { break unless task_class_a.locks.empty?; sleep 0.01 }
          expect(task_class_a.locks).not_to be_empty
          expect(queue).to be_working

          task_class_a.locks.values.last << true

          100.times { break unless queue.working?; sleep 0.01 }
          expect(queue).not_to be_working
        end
      end

    end
  end
end
