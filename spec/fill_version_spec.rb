require 'English'
require 'json'
require 'tempfile'
require 'spec_helper'
require 'helpers/git_helper'
require 'helpers/tmp_dir_helper'

RSpec.describe 'fill-version' do
  command = File.join(Dir.pwd, 'bin', 'fill-version').freeze

  it 'prints version to STDOUT on --version' do
    s = `#{command} --version`
    expect($CHILD_STATUS.success?).to be(true)
    expect(s.strip).to match(/[\d\.]+/)
  end

  ['-h', '--help'].each do |opt|
    it "prints help to STDERR on #{opt}" do
      s = `#{command} #{opt} 2>&1 1>/dev/null`
      expect($CHILD_STATUS.success?).to be(true)
      expect(s).to eq(<<~OUT)
        usage: #{File.basename(command)} [in_erb_file] [out_file] [options]
          -h, --help                       print help
          --version                        print the version
          -k, --ksp-version [ksp version]  KSP version
          -m, --mod-version [mod version]  mod version
          -v, --verbose                    verbose logging
      OUT
    end
  end

  it 'exits with status 1 when there are too many arguments' do
    s = `#{command} abc def ghi 2>&1 1>/dev/null`
    expect($CHILD_STATUS.success?).to be(false)
    expect($CHILD_STATUS.exitstatus).to eq(1)
    expect(s).to eq(<<~OUT)
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
        s = `export KSP_VERSION_MAX=1.2.3 && echo '^^<%= ksp_version %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    it 'can read it from KSP_VERSION file' do
      in_tmp_dir do
        File.write('KSP_VERSION', "1.2.3\n")
        File.write('KSP_VERSION.json', { 'ksp_version_max' => '2.3.4' }.to_json)
        s = `echo '^^<%= ksp_version %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    it 'can read it from KSP_VERSION.json file' do
      in_tmp_dir do
        File.write('KSP_VERSION', "2.3.4\n")
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '1.2.3', 'ksp_version_max' => '2.3.4' }.to_json)
        s = `echo '^^<%= ksp_version %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    it 'can read it from KSP_VERSION environment variable' do
      in_tmp_dir do
        File.write('KSP_VERSION', "2.3.4\n")
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '2.3.4', 'ksp_version_max' => '2.3.4' }.to_json)
        s = `export KSP_VERSION=1.2.3 && echo '^^<%= ksp_version.to_s %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    ['-k', '--ksp-version'].each do |opt|
      it "can read it from #{opt}" do
        in_tmp_dir do
          File.write('KSP_VERSION', "2.3.4\n")
          File.write('KSP_VERSION.json', { 'KSP_VERSION' => '2.3.4', 'ksp_version_max' => '2.3.4' }.to_json)
          s = `export KSP_VERSION=2.3.4 && echo '^^<%= ksp_version %>$$' | #{command} #{opt} 1.2.3 -m 0.0.0`
          expect($CHILD_STATUS.success?).to be(true)
          expect(s.strip).to eq('^^1.2.3$$')
        end
      end
    end

    it 'exits with status 1 when ksp version cannot be determined' do
      s = `#{command} -m 0.0.0 2>&1 1>/dev/null`
      expect($CHILD_STATUS.success?).to be(false)
      expect($CHILD_STATUS.exitstatus).to eq(1)
      expect(s.strip).to eq('ksp version not specified and no way to determine it')
    end
  end

  context 'ksp_version_min' do
    it 'can read it from KSP_VERSION.json file' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION_MIN' => '1.2.3', 'KSP_VERSION' => '2.3.4' }.to_json)
        s = `echo '^^<%= ksp_version_min %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    it 'can read it from KSP_VERSION_MIN environment variable' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION_MIN' => '2.3.4', 'KSP_VERSION' => '3.4.5' }.to_json)
        s = `export KSP_VERSION_MIN=1.2.3 && echo '^^<%= ksp_version_min %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    it 'uses ksp_version if none is specified' do
      s = `echo '^^<%= ksp_version_min %>$$' | #{command} -k 1.2.3 -m 0.0.0`
      expect($CHILD_STATUS.success?).to be(true)
      expect(s.strip).to eq('^^1.2.3$$')
    end
  end

  context 'ksp_version_max' do
    it 'can read it from KSP_VERSION.json file' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '1.2.3', 'KSP_VERSION_MAX' => '2.3.4' }.to_json)
        s = `echo '^^<%= ksp_version_max %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^2.3.4$$')
      end
    end

    it 'can read it from KSP_VERSION_MAX environment variable' do
      in_tmp_dir do
        File.write('KSP_VERSION.json', { 'KSP_VERSION' => '1.2.3', 'KSP_VERSION_MAX' => '2.3.4' }.to_json)
        s = `export KSP_VERSION_MAX=3.4.5 && echo '^^<%= ksp_version_max %>$$' | #{command} -m 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^3.4.5$$')
      end
    end

    it 'uses ksp_version if none is specified' do
      s = `echo '^^<%= ksp_version_max %>$$' | #{command} -k 1.2.3 -m 0.0.0`
      expect($CHILD_STATUS.success?).to be(true)
      expect(s.strip).to eq('^^1.2.3$$')
    end
  end

  context 'mod version' do
    it 'can read from git tags' do
      in_git_dir(commits: 1, tag: 'v1.2.3', commits_since_tag: 1) do
        s = `echo '^^<%= mod_version %>$$' | #{command} -k 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3.1$$')
      end
    end

    it 'can read it from MOD_VERSION environment variable' do
      in_git_dir(commits: 1, tag: 'v2.3.4', commits_since_tag: 1) do
        s = `export MOD_VERSION=1.2.3 && echo '^^<%= mod_version %>$$' | #{command} -k 0.0.0`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3$$')
      end
    end

    ['-m', '--mod-version'].each do |opt|
      it "can read it from #{opt}" do
        in_git_dir(commits: 1, tag: 'v2.3.4', commits_since_tag: 1) do
          s = `export MOD_VERSION=2.3.4 && echo '^^<%= mod_version %>$$' | #{command} -k 0.0.0 #{opt} 1.2.3`
          expect($CHILD_STATUS.success?).to be(true)
          expect(s.strip).to eq('^^1.2.3$$')
        end
      end
    end

    it 'exits with status 1 when mod version cannot be determined' do
      in_tmp_dir do
        s = `#{command} -k 0.0.0 2>&1 1>/dev/null`
        expect($CHILD_STATUS.success?).to be(false)
        expect($CHILD_STATUS.exitstatus).to eq(1)
        expect(s.strip).to eq('mod version not specified and no way to determine it')
      end
    end
  end

  it 'reads from an input file' do
    Tempfile.open(['template', '.erb']) do |tempfile|
      tempfile.write('^^<%= ksp_version %>&&<%= mod_version %>$$')
      tempfile.flush
      s = `#{command} '#{tempfile.path}' -k 1.2.3 -m 2.3.4`
      expect($CHILD_STATUS.success?).to be(true)
      expect(s.strip).to eq('^^1.2.3&&2.3.4$$')
    end
  end

  it 'reads from an input file and prints to an output file' do
    Tempfile.open(['template', '.erb']) do |infile|
      Tempfile.open('output') do |outfile|
        infile.write('^^<%= ksp_version %>&&<%= mod_version %>$$')
        infile.flush
        s = `#{command} '#{infile.path}' '#{outfile.path}' -k 1.2.3 -m 2.3.4`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s).to be_empty

        expect(File.read(outfile.path).strip).to eq('^^1.2.3&&2.3.4$$')
      end
    end
  end

  it 'exits with status 1 if a file is specified but it does not exist' do
    s = `#{command} -k 0.0.0 -m 0.0.0 'fake_file' 2>&1 1>/dev/null`
    expect($CHILD_STATUS.success?).to be(false)
    expect($CHILD_STATUS.exitstatus).to eq(1)
    expect(s.strip).to eq("file does not exist: 'fake_file'")
  end

  context 'version' do
    context 'major' do
      it 'returns the major version' do
        input = '^^<%= ksp_version.major %>&&<%= mod_version.major %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 4.5.6`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1&&4$$')
      end
    end

    context 'minor' do
      it 'returns the minor version' do
        input = '^^<%= ksp_version.minor %>&&<%= mod_version.minor %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 4.5.6`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^2&&5$$')
      end

      it 'returns nil if no minor version specified' do
        input = '^^<%= ksp_version.minor.inspect %>&&<%= mod_version.minor.inspect %>$$'
        s = `echo '#{input}' | #{command} -k 1 -m 4`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^nil&&nil$$')
      end

      it 'returns an override if no minor version specified but an override is specified' do
        input = '^^<%= ksp_version.minor(888) %>&&<%= mod_version.minor(999) %>$$'
        s = `echo '#{input}' | #{command} -k 1 -m 4`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^888&&999$$')
      end
    end

    context 'patch' do
      it 'returns the patch version' do
        input = '^^<%= ksp_version.patch %>&&<%= mod_version.patch %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 4.5.6`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^3&&6$$')
      end

      it 'returns nil if no patch version specified' do
        input = '^^<%= ksp_version.patch.inspect %>&&<%= mod_version.patch.inspect %>$$'
        s = `echo '#{input}' | #{command} -k 1.2 -m 4.5`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^nil&&nil$$')
      end

      it 'returns an override if no patch version specified but an override is specified' do
        input = '^^<%= ksp_version.patch(888) %>&&<%= mod_version.patch(999) %>$$'
        s = `echo '#{input}' | #{command} -k 1.2 -m 4.5`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^888&&999$$')
      end
    end

    context 'build' do
      it 'returns the build version' do
        input = '^^<%= ksp_version.build %>&&<%= mod_version.build %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3.4 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^4&&8$$')
      end

      it 'returns nil if no build version specified' do
        input = '^^<%= ksp_version.build.inspect %>&&<%= mod_version.build.inspect %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^nil&&nil$$')
      end

      it 'returns an override if no build version specified but an override is specified' do
        input = '^^<%= ksp_version.build(888) %>&&<%= mod_version.build(999) %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^888&&999$$')
      end
    end

    context 'indexer' do
      it 'returns the version number at a particular index' do
        input = '^^<%= ksp_version[1] %>&&<%= mod_version[2] %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3.4 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^2&&7$$')
      end

      it 'returns nil if the version number at a particular index is not specified' do
        input = '^^<%= ksp_version[3].inspect %>&&<%= mod_version[99].inspect %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^nil&&nil$$')
      end

      it 'returns an override if the version number at a particular index specified but an override is specified' do
        input = '^^<%= ksp_version[3, 888] %>&&<%= mod_version[99, 999] %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^888&&999$$')
      end
    end

    context to_s do
      it 'returns the full version' do
        input = '^^<%= ksp_version.to_s %>&&<%= mod_version.to_s %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3&&5.6.7.8$$')
      end

      it 'drops version numbers beyond a specified limit' do
        input = '^^<%= ksp_version.to_s(2) %>&&<%= mod_version.to_s(1) %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2&&5$$')
      end

      it 'pads version with zeros up to the specified limit' do
        input = '^^<%= ksp_version.to_s(4) %>&&<%= mod_version.to_s(6) %>$$'
        s = `echo '#{input}' | #{command} -k 1.2.3 -m 5.6.7.8`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s.strip).to eq('^^1.2.3.0&&5.6.7.8.0.0$$')
      end
    end
  end
end
