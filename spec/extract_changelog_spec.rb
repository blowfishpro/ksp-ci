# frozen_string_literal: true

require 'spec_helper'

require 'open3'
require 'tempfile'

VERSION_DATA = <<~MARKDOWN
  # Changelog

  some text

  ### v1.1.1

  * fix a bug
  * fix another bug

  ### v1.1.0

  * add a feature
  * fix a bug

  ### v1.0.0

  * Initial release
MARKDOWN

RSpec.describe 'fill-version' do
  command = File.join(Dir.pwd, 'bin', 'extract-changelog').freeze

  it 'prints version to STDOUT on --version' do
    output, _, status = Open3.capture3("#{command} --version")
    expect(status.success?).to be(true)
    expect(output.strip).to match(/[\d\.]+/)
  end

  it 'prints help to STDERR on --help' do
    stdout, stderr, status = Open3.capture3("#{command} --help")
    expect(status.success?).to be(true)
    expect(stdout).to be_empty
    expect(stderr).to match(/usage:/)
  end

  it 'gets all the versions up to a particular version' do
    output, _, status = Open3.capture3("#{command} --upto-version v1.1.0", stdin_data: VERSION_DATA)
    expect(status.success?).to be(true)

    expected_output = <<~MARKDOWN
      ### v1.1.0

      * add a feature
      * fix a bug

      ### v1.0.0

      * Initial release
    MARKDOWN
    expect(output).to eq(expected_output)
  end

  it 'gets just one version' do
    output, _, status = Open3.capture3("#{command} --single-version v1.1.0", stdin_data: VERSION_DATA)
    expect(status.success?).to be(true)

    expected_output = <<~MARKDOWN
      ### v1.1.0

      * add a feature
      * fix a bug
    MARKDOWN
    expect(output).to eq(expected_output)
  end

  it 'uses an input file' do
    Tempfile.open(['changelog', '.md']) do |tempfile|
      tempfile.write VERSION_DATA
      tempfile.flush
      output, _, status = Open3.capture3("#{command} -s v1.1.0 --in-file '#{tempfile.path}'")
      expect(status.success?).to be(true)

      expected_output = <<~MARKDOWN
        ### v1.1.0

        * add a feature
        * fix a bug
      MARKDOWN
      expect(output).to eq(expected_output)
    end
  end

  it 'uses an output file' do
    Tempfile.open(['changelog', '.md']) do |tempfile|
      output, _, status = Open3.capture3("#{command} -s v1.1.0 --out-file '#{tempfile.path}'", stdin_data: VERSION_DATA)
      expect(status.success?).to be(true)
      expect(output).to be_empty

      expected_output = <<~MARKDOWN
        ### v1.1.0

        * add a feature
        * fix a bug
      MARKDOWN
      expect(File.read(tempfile.path)).to eq(expected_output)
    end
  end

  it 'complains if both upto version and single version are specified' do
    _, _, status = Open3.capture3("#{command} -s v1.1.0 -u v1.1.0", stdin_data: VERSION_DATA)
    expect(status.success?).to be(false)
  end

  it 'complains if neither upto version and single version are specified' do
    _, _, status = Open3.capture3(command, stdin_data: VERSION_DATA)
    expect(status.success?).to be(false)
  end

  it 'complains with empty input' do
    _, _, status = Open3.capture3("#{command} --single-version v1.1.0")
    expect(status.success?).to be(false)
  end

  it 'complains with an input version that is not matched' do
    _, _, status = Open3.capture3("#{command} --single-version v1.0.1", stdin_data: VERSION_DATA)
    expect(status.success?).to be(false)
  end

  it 'complains with a version upto that matches other versions but not that exact version' do
    _, _, status = Open3.capture3("#{command} --single-version v1.0.1", stdin_data: VERSION_DATA)
    expect(status.success?).to be(false)
  end

  it 'complains with a version upto that matches no version' do
    _, _, status = Open3.capture3("#{command} --single-version v0.9", stdin_data: VERSION_DATA)
    expect(status.success?).to be(false)
  end
end