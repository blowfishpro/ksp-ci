require 'English'
require 'json'
require 'tempfile'
require 'spec_helper'

RSpec.describe 'install-netkan-deps' do
  command = File.join(Dir.pwd, 'bin', 'install-netkan-deps').freeze

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
        usage: #{File.basename(command)} [ckan_ksp_name] [netkan_file] [options]
            -h, --help                  print help
            --version                   print the version
            -x, --exclude [identifier]  exclude mod with this identifier (do not install)
            -v, --verbose               verbose logging
      OUT
    end
  end

  it 'exits with status 1 if wrong number of arguments are provided' do
    s = `#{command} a b c 2>&1 1>/dev/null`
    expect($CHILD_STATUS.success?).to be(false)
    expect($CHILD_STATUS.exitstatus).to eq(1)
    expect(s).to eq(<<~OUT)
      Wrong number of arguments
      usage: #{File.basename(command)} [ckan_ksp_name] [netkan_file] [options]
          -h, --help                  print help
          --version                   print the version
          -x, --exclude [identifier]  exclude mod with this identifier (do not install)
          -v, --verbose               verbose logging
    OUT
  end

  it 'exits with status 1 if netkan file does not exist' do
    Dir.mktmpdir('ksp_dir') do |ksp_dir|
      s = `#{command} '#{ksp_dir}' 'does_not_exist' 2>&1 1>/dev/null`
      expect($CHILD_STATUS.success?).to be(false)
      expect($CHILD_STATUS.exitstatus).to eq(1)
      expect(s.strip).to eq("'does_not_exist' is not a file")
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
          '2>&1 1>/dev/null',
        ].join(' ')
        s = `#{run_command}`
        expect($CHILD_STATUS.success?).to be(true)
        expect(s).to eq(<<~OUTPUT)
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
