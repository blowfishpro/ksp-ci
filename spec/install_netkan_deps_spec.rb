# frozen_string_literal: true

require 'json'
require 'open3'
require 'tempfile'
require 'spec_helper'

RSpec.describe 'install-netkan-deps' do
  command = File.join(Dir.pwd, 'bin', 'install-netkan-deps').freeze

  it 'prints version to STDOUT on --version' do
    stdout, stderr, status = Open3.capture3 "#{command} --version"
    expect(status.success?).to be(true)
    expect(stdout.strip).to match(/[\d\.]+/)
    expect(stderr).to be_empty
  end

  ['-h', '--help'].each do |opt|
    it "prints help to STDERR on #{opt}" do
      stdout, stderr, status = Open3.capture3 "#{command} #{opt}"
      expect(status.success?).to be(true)
      expect(stdout).to be_empty
      expect(stderr).to eq(<<~OUT)
        usage: #{File.basename(command)} [ckan_ksp_name] [netkan_file] [options]
            -h, --help                  print help
            --version                   print the version
            -x, --exclude [identifier]  exclude mod with this identifier (do not install)
            -v, --verbose               verbose logging
      OUT
    end
  end

  it 'fails if wrong number of arguments are provided' do
    stdout, stderr, status = Open3.capture3 "#{command} a b c"
    expect(status.success?).to be(false)
    expect(stdout).to be_empty
    expect(stderr).to eq(<<~OUT)
      Wrong number of arguments
      usage: #{File.basename(command)} [ckan_ksp_name] [netkan_file] [options]
          -h, --help                  print help
          --version                   print the version
          -x, --exclude [identifier]  exclude mod with this identifier (do not install)
          -v, --verbose               verbose logging
    OUT
  end

  it 'fails if netkan file does not exist' do
    Dir.mktmpdir('ksp_dir') do |ksp_dir|
      stdout, stderr, status = Open3.capture3 "#{command} '#{ksp_dir}' 'does_not_exist'"
      expect(status.success?).to be(false)
      expect(stdout).to be_empty
      expect(stderr.strip).to eq("'does_not_exist' is not a file")
    end
  end

  it 'Installs dependencies from netkan file, excluding those specified by -x or --exclude' do
    Dir.mktmpdir('tmp_path') do |tmp_path_dir|
      ckan_command = File.join(tmp_path_dir, 'ckan')
      File.open(ckan_command, 'w') do |file|
        file.write <<~SH
          #!/usr/bin/env sh
          set -e
          echo "<ckan $@>"
        SH
      end
      FileUtils.chmod '+x', ckan_command

      Tempfile.open(['blah', '.netkan']) do |netkan_file|
        netkan_file.write(
          {
            depends: [
              { name: 'mod1' },
              { name: 'mod2' },
              { name: 'mod3' },
              { name: 'mod4' },
              { name: 'mod5' },
              { name: 'mod6' },
              { name: 'mod7' },
              { name: 'mod8' },
            ],
          }.to_json,
        )
        netkan_file.flush

        run_command = [
          "PATH=\"#{tmp_path_dir}:${PATH}\"",
          "#{command} 'some_ksp_instance' '#{netkan_file.path}' -x mod3 -x mod4 --exclude mod5 --exclude mod6",
        ].join(' ')
        stdout, stderr, status = Open3.capture3 run_command
        expect(status.success?).to be(true)
        expect(stdout).to be_empty
        expect(stderr).to eq(<<~OUTPUT)
          Installing NetKAN dependencies in CKAN KSP instance 'some_ksp_instance' from NetKAN file '#{netkan_file.path}'
          Installing mod1
          <ckan install --headless --no-recommends --ksp some_ksp_instance mod1>
          Installing mod2
          <ckan install --headless --no-recommends --ksp some_ksp_instance mod2>
          Installing mod7
          <ckan install --headless --no-recommends --ksp some_ksp_instance mod7>
          Installing mod8
          <ckan install --headless --no-recommends --ksp some_ksp_instance mod8>
        OUTPUT
      end
    end
  end
end
