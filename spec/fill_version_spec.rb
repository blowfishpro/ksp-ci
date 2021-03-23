# frozen_string_literal: true

require 'json'
require 'tempfile'
require 'spec_helper'
require 'helpers/git_helper'
require 'helpers/tmp_dir_helper'
require 'helpers/virtual_script_executor'

RSpec.describe 'fill-version' do
  command = File.join(Dir.pwd, 'bin', 'fill-version').freeze

  it 'prints version to STDOUT on --version' do
    stdout, stderr, status = execute_script command, '--version'
    expect(status.success?).to be(true)
    expect(stdout.strip).to match(/[\d.]+/)
    expect(stderr).to be_empty
  end

  ['-h', '--help'].each do |opt|
    it "prints help to STDERR on #{opt}" do
      stdout, stderr, status = execute_script command, opt
      expect(status.success?).to be(true)
      expect(stdout).to be_empty
      expect(stderr).to eq(<<~OUT)
        usage: #{File.basename(command)} [in_erb_file] [out_file] [options]
          -h, --help                       print help
          --version                        print the version
          -k, --ksp-version [ksp version]  KSP version
          -m, --mod-version [mod version]  mod version
          -v, --verbose                    verbose logging
      OUT
    end
  end

  it 'fails when there are too many arguments' do
    stdout, stderr, status = execute_script command, 'abc', 'def', 'ghi'
    expect(status.success?).to be(false)
    expect(stdout).to be_empty
    expect(stderr).to eq(<<~OUT)
      Error: Too many arguments
      usage: #{File.basename(command)} [in_erb_file] [out_file] [options]
        -h, --help                       print help
        --version                        print the version
        -k, --ksp-version [ksp version]  KSP version
        -m, --mod-version [mod version]  mod version
        -v, --verbose                    verbose logging
    OUT
  end

  context 'ksp version' do
    it 'uses KSP_VERSION_MAX if nothing else is specified' do
      in_tmp_dir do
        stdout, stderr, status = execute_script(
          command, '-m', '0.0.0',
          stdin_data: '^^<%= ksp_version %>$$',
          env: { 'KSP_VERSION_MAX' => '1.2.3' },
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    it 'can read it from KSP_VERSION file' do
      in_tmp_dir do
        File.write('KSP_VERSION', "1.2.3\n")
        File.write('KSP_VERSION.json', { 'ksp_version_max' => '2.3.4' }.to_json)
        stdout, stderr, status = execute_script command, '-m', '0.0.0', stdin_data: '^^<%= ksp_version %>$$'
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    it 'can read it from KSP_VERSION.json file' do
      in_tmp_dir do
        File.write('KSP_VERSION', "2.3.4\n")
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '1.2.3', 'ksp_version_max' => '2.3.4' }.to_json)
        stdout, stderr, status = execute_script command, '-m', '0.0.0', stdin_data: '^^<%= ksp_version %>$$'
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    it 'can read it from KSP_VERSION environment variable' do
      in_tmp_dir do
        File.write('KSP_VERSION', "2.3.4\n")
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '2.3.4', 'ksp_version_max' => '2.3.4' }.to_json)
        stdout, stderr, status = execute_script(
          command, '-m', '0.0.0',
          stdin_data: '^^<%= ksp_version %>$$',
          env: { 'KSP_VERSION' => '1.2.3' },
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    ['-k', '--ksp-version'].each do |opt|
      it "can read it from #{opt}" do
        in_tmp_dir do
          File.write('KSP_VERSION', "2.3.4\n")
          File.write('KSP_VERSION.json', { 'KSP_VERSION' => '2.3.4', 'ksp_version_max' => '2.3.4' }.to_json)
          stdout, stderr, status = execute_script(
            command, opt, '1.2.3', '-m', '0.0.0',
            stdin_data: '^^<%= ksp_version %>$$',
            env: { 'KSP_VERSION' => '2.3.4' },
          )
          expect(status.success?).to be(true)
          expect(stdout.strip).to eq('^^1.2.3$$')
          expect(stderr).to be_empty
        end
      end
    end

    it 'fails when it cannot be determined' do
      stdout, stderr, status = execute_script command, '-m', '0.0.0'
      expect(status.success?).to be(false)
      expect(stdout).to be_empty
      expect(stderr.strip).to eq('ksp version not specified and no way to determine it')
    end
  end

  context 'ksp_version_min' do
    it 'can read it from KSP_VERSION.json file' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION_MIN' => '1.2.3', 'KSP_VERSION' => '2.3.4' }.to_json)
        stdout, stderr, status = execute_script command, '-m', '0.0.0', stdin_data: '^^<%= ksp_version_min %>$$'
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    it 'can read it from KSP_VERSION_MIN environment variable' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION_MIN' => '2.3.4', 'KSP_VERSION' => '3.4.5' }.to_json)
        stdout, stderr, status = execute_script(
          command, '-m', '0.0.0',
          stdin_data: '^^<%= ksp_version_min %>$$',
          env: { 'KSP_VERSION_MIN' => '1.2.3' },
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    it 'uses ksp_version if none is specified' do
      stdout, stderr, status = execute_script(
        command, '-k', '1.2.3', '-m', '0.0.0',
        stdin_data: '^^<%= ksp_version_min %>$$',
      )
      expect(status.success?).to be(true)
      expect(stdout.strip).to eq('^^1.2.3$$')
      expect(stderr).to be_empty
    end
  end

  context 'ksp_version_max' do
    it 'can read it from KSP_VERSION.json file' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '1.2.3', 'KSP_VERSION_MAX' => '2.3.4' }.to_json)
        stdout, stderr, status = execute_script command, '-m', '0.0.0', stdin_data: '^^<%= ksp_version_max %>$$'
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^2.3.4$$')
        expect(stderr).to be_empty
      end
    end

    it 'can read it from KSP_VERSION_MAX environment variable' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '1.2.3', 'KSP_VERSION_MAX' => '2.3.4' }.to_json)
        stdout, stderr, status = execute_script(
          command, '-m', '0.0.0',
          stdin_data: '^^<%= ksp_version_max %>$$',
          env: { 'KSP_VERSION_MAX' => '3.4.5' },
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^3.4.5$$')
        expect(stderr).to be_empty
      end
    end

    it 'uses ksp_version if none is specified' do
      stdout, stderr, status = execute_script(
        command, '-k', '1.2.3', '-m', '0.0.0',
        stdin_data: '^^<%= ksp_version_max %>$$',
      )
      expect(status.success?).to be(true)
      expect(stdout.strip).to eq('^^1.2.3$$')
      expect(stderr).to be_empty
    end
  end

  context 'mod version' do
    it 'can read from git tags' do
      in_git_dir(commits: 1, tag: 'v1.2.3', commits_since_tag: 1) do
        stdout, stderr, status = execute_script command, '-k', '0.0.0', stdin_data: '^^<%= mod_version %>$$'
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3.1$$')
        expect(stderr).to be_empty
      end
    end

    it 'can read it from MOD_VERSION environment variable' do
      in_git_dir(commits: 1, tag: 'v2.3.4', commits_since_tag: 1) do
        stdout, stderr, status = execute_script(
          command, '-k', '0.0.0',
          stdin_data: '^^<%= mod_version %>$$',
          env: { 'MOD_VERSION' => '1.2.3' },
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3$$')
        expect(stderr).to be_empty
      end
    end

    ['-m', '--mod-version'].each do |opt|
      it "can read it from #{opt}" do
        in_git_dir(commits: 1, tag: 'v2.3.4', commits_since_tag: 1) do
          stdout, stderr, status = execute_script(
            command, '-k', '0.0.0', opt, '1.2.3',
            stdin_data: '^^<%= mod_version %>$$',
            env: { 'MOD_VERSION' => '2.3.4' },
          )
          expect(status.success?).to be(true)
          expect(stdout.strip).to eq('^^1.2.3$$')
          expect(stderr).to be_empty
        end
      end
    end

    it 'fails when it cannot be determined' do
      in_tmp_dir do
        stdout, stderr, status = execute_script command, '-k', '0.0.0'
        expect(status.success?).to be(false)
        expect(stdout).to be_empty
        expect(stderr.strip).to eq('mod version not specified and no way to determine it')
      end
    end
  end

  context 'git version' do
    it 'is nil when not in a git directory' do
      in_tmp_dir do
        stdout, stderr, status = execute_script(
          command, '-k', '0.0.0', '-m', '0.0.0',
          stdin_data: '^^<%= git_version.nil? %>$$',
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^true$$')
        expect(stderr).to be_empty
      end
    end

    it 'contains the full git version when in a git directory' do
      in_git_dir(commits: 1, tag: 'v1.2.3', commits_since_tag: 1) do
        git_revision, status = Open3.capture2 'git rev-parse HEAD'
        expect(status.success?).to be(true)

        stdout, stderr, status = execute_script(
          command, '-k', '0.0.0', '-m', '0.0.0',
          stdin_data: '^^<%= git_version %>$$',
        )
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq("^^v1.2.3-1-g#{git_revision[0...7]}$$")
        expect(stderr).to be_empty
      end
    end
  end

  it 'reads from an input file' do
    Tempfile.open(['template', '.erb']) do |tempfile|
      tempfile.write('^^<%= ksp_version %>&&<%= mod_version %>$$')
      tempfile.flush
      stdout, stderr, status = execute_script command, tempfile.path, '-k', '1.2.3', '-m', '2.3.4'
      expect(status.success?).to be(true)
      expect(stdout.strip).to eq('^^1.2.3&&2.3.4$$')
      expect(stderr).to be_empty
    end
  end

  it 'reads from an input file and prints to an output file' do
    Tempfile.open(['template', '.erb']) do |infile|
      Tempfile.open('output') do |outfile|
        infile.write('^^<%= ksp_version %>&&<%= mod_version %>$$')
        infile.flush

        stdout, stderr, status = execute_script command, infile.path, outfile.path, '-k', '1.2.3', '-m', '2.3.4'
        expect(status.success?).to be(true)
        expect(stdout).to be_empty
        expect(stderr).to be_empty

        expect(File.read(outfile.path).strip).to eq('^^1.2.3&&2.3.4$$')
      end
    end
  end

  it 'fails if a file is specified but it does not exist' do
    stdout, stderr, status = execute_script command, '-k', '0.0.0', '-m', '0.0.0', 'fake_file'
    expect(status.success?).to be(false)
    expect(stdout).to be_empty
    expect(stderr.strip).to eq("file does not exist: 'fake_file'")
  end

  context 'version' do
    context 'major' do
      it 'returns the major version' do
        input = '^^<%= ksp_version.major %>&&<%= mod_version.major %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '4.5.6', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1&&4$$')
        expect(stderr).to be_empty
      end
    end

    context 'minor' do
      it 'returns the minor version' do
        input = '^^<%= ksp_version.minor %>&&<%= mod_version.minor %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '4.5.6', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^2&&5$$')
        expect(stderr).to be_empty
      end

      it 'returns nil if no minor version specified' do
        input = '^^<%= ksp_version.minor.nil? %>&&<%= mod_version.minor.nil? %>$$'
        stdout, stderr, status = execute_script command, '-k', '1', '-m', '4', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^true&&true$$')
        expect(stderr).to be_empty
      end

      it 'returns an override if no minor version specified but an override is specified' do
        input = '^^<%= ksp_version.minor(888) %>&&<%= mod_version.minor(999) %>$$'
        stdout, stderr, status = execute_script command, '-k', '1', '-m', '4', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^888&&999$$')
        expect(stderr).to be_empty
      end
    end

    context 'patch' do
      it 'returns the patch version' do
        input = '^^<%= ksp_version.patch %>&&<%= mod_version.patch %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '4.5.6', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^3&&6$$')
        expect(stderr).to be_empty
      end

      it 'returns nil if no patch version specified' do
        input = '^^<%= ksp_version.patch.nil? %>&&<%= mod_version.patch.nil? %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2', '-m', '4.5', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^true&&true$$')
        expect(stderr).to be_empty
      end

      it 'returns an override if no patch version specified but an override is specified' do
        input = '^^<%= ksp_version.patch(888) %>&&<%= mod_version.patch(999) %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2', '-m', '4.4', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^888&&999$$')
        expect(stderr).to be_empty
      end
    end

    context 'build' do
      it 'returns the build version' do
        input = '^^<%= ksp_version.build %>&&<%= mod_version.build %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3.4', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^4&&8$$')
        expect(stderr).to be_empty
      end

      it 'returns nil if no build version specified' do
        input = '^^<%= ksp_version.build.nil? %>&&<%= mod_version.build.nil? %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^true&&true$$')
        expect(stderr).to be_empty
      end

      it 'returns an override if no build version specified but an override is specified' do
        input = '^^<%= ksp_version.build(888) %>&&<%= mod_version.build(999) %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^888&&999$$')
        expect(stderr).to be_empty
      end
    end

    context 'indexer' do
      it 'returns the version number at a particular index' do
        input = '^^<%= ksp_version[1] %>&&<%= mod_version[2] %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3.4', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^2&&7$$')
        expect(stderr).to be_empty
      end

      it 'returns nil if the version number at a particular index is not specified' do
        input = '^^<%= ksp_version[3].nil? %>&&<%= mod_version[99].nil? %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^true&&true$$')
        expect(stderr).to be_empty
      end

      it 'returns an override if the version number at a particular index specified but an override is specified' do
        input = '^^<%= ksp_version[3, 888] %>&&<%= mod_version[99, 999] %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^888&&999$$')
        expect(stderr).to be_empty
      end
    end

    context to_s do
      it 'returns the full version' do
        input = '^^<%= ksp_version.to_s %>&&<%= mod_version.to_s %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3&&5.6.7.8$$')
        expect(stderr).to be_empty
      end

      it 'drops version numbers beyond a specified limit' do
        input = '^^<%= ksp_version.to_s(2) %>&&<%= mod_version.to_s(1) %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2&&5$$')
        expect(stderr).to be_empty
      end

      it 'pads version with zeros up to the specified limit' do
        input = '^^<%= ksp_version.to_s(4) %>&&<%= mod_version.to_s(6) %>$$'
        stdout, stderr, status = execute_script command, '-k', '1.2.3', '-m', '5.6.7.8', stdin_data: input
        expect(status.success?).to be(true)
        expect(stdout.strip).to eq('^^1.2.3.0&&5.6.7.8.0.0$$')
        expect(stderr).to be_empty
      end
    end
  end
end
