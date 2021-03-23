# frozen_string_literal: true

require 'stringio'

class VirtualScriptExecutor
  class CommandExited < RuntimeError
    attr_reader :status

    def initialize(status)
      super("script exited with code #{status}")
      @status = status
    end
  end

  class ExitStatus
    attr_reader :status

    def initialize(status)
      @status = status
    end

    def success?
      @status.zero?
    end

    alias zero? success?

    def ==(other)
      case other
      when self.class
        status == other.status
      when Integer
        status == other
      else
        false
      end
    end
  end

  class ScriptEvaluator
    private

    def exit(status = 0)
      raise CommandExited, status
    end
  end

  module RspecHelper
    def execute_script(*args, **kwargs)
      VirtualScriptExecutor.new.call(*args, **kwargs)
    end
  end

  def call(filename, *args, env: {}, stdin_data: nil) # rubocop:disable Metrics/MethodLength
    contents = File.read(filename)
    evaluator = ScriptEvaluator.new
    stdout, stderr, status = nil
    with_program_name(filename) do
      with_args(*args) do
        with_env(**env) do
          stdout = capturing_stdout do
            stderr = capturing_stderr do
              with_stdin(stdin_data) do
                status = returning_status do
                  evaluator.instance_eval(contents, filename, 0)
                end
              end
            end
          end
        end
      end
    end

    [stdout, stderr, status]
  end

  private

  def with_program_name(filename)
    program_name = $PROGRAM_NAME
    $PROGRAM_NAME = filename
    yield
  ensure
    $PROGRAM_NAME = program_name
  end

  def with_args(*args)
    original_argv = ARGV.dup
    ARGV.replace args
    yield
  ensure
    ARGV.replace original_argv
  end

  def with_env(**env)
    original_env = ENV.to_h
    ENV.merge!(env)
    yield
  ensure
    ENV.replace original_env
  end

  def capturing_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  def capturing_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end

  def with_stdin(data)
    original_stdin = $stdin
    $stdin = data.respond_to?(:read) ? data : StringIO.new(data.to_s)
    yield
  ensure
    $stdin = original_stdin
  end

  def returning_status
    yield
    ExitStatus.new(0)
  rescue CommandExited => e
    ExitStatus.new(e.status)
  end
end

RSpec.configure do |config|
  config.include VirtualScriptExecutor::RspecHelper
end
