require 'English'
require 'open3'
require 'tempfile'
require 'spec_helper'

RSpec.describe 'make-ksp-install' do
  command = File.join(Dir.pwd, 'bin', 'make-ksp-install').freeze

  it 'creates a dummy KSP directory' do
    Dir.mktmpdir('tmp_path') do |tmp_path_dir|
      ckan_command = File.join(tmp_path_dir, 'ckan')
      Tempfile.open do |ckan_command_log|
        File.open(ckan_command, 'w') do |file|
          file.write <<~SH
            #!/usr/bin/env sh
            set -e
            echo "ckan ${@}" >> '#{ckan_command_log.path}'
          SH
        end
        FileUtils.chmod '+x', ckan_command

        Dir.mktmpdir('ksp_install_tmp') do |ksp_install_tmp|
          ksp_install_dir = File.join(ksp_install_tmp, 'dummy_ksp_install_dir')
          run_command = [
            "PATH=\"#{tmp_path_dir}:${PATH}\"",
            "#{command} '#{ksp_install_dir}' 'dummy_ksp_install' '1.2.3'",
          ].join(' ')
          _, _, status = Open3.capture3(run_command)
          expect(status.success?).to be(true)
          expect(File.read(ckan_command_log.path)).to eq(<<~CMD)
            ckan ksp forget dummy_ksp_install
            ckan ksp add dummy_ksp_install #{ksp_install_dir}
            ckan update --ksp dummy_ksp_install
          CMD
          expect(Dir.exist?(ksp_install_dir)).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'CKAN'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'GameData'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'Ships'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'Ships', 'VAB'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'Ships', 'SPH'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'Ships', '@thumbs'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'Ships', '@thumbs', 'VAB'))).to be(true)
          expect(Dir.exist?(File.join(ksp_install_dir, 'Ships', '@thumbs', 'SPH'))).to be(true)
          expect(File.read(File.join(ksp_install_dir, 'readme.txt'))).to eq('Version 1.2.3')
        end
      end
    end
  end

  it 'removes the dummy KSP directory if it already exists' do
    Dir.mktmpdir('tmp_path') do |tmp_path_dir|
      ckan_command = File.join(tmp_path_dir, 'ckan')
      Tempfile.open do |ckan_command_log|
        File.open(ckan_command, 'w') do |file|
          file.write <<~SH
            #!/usr/bin/env sh
            set -e
            echo "ckan ${@}" >> '#{ckan_command_log.path}'
          SH
        end
        FileUtils.chmod '+x', ckan_command

        Dir.mktmpdir('ksp_install_tmp') do |ksp_install_tmp|
          ksp_install_dir = File.join(ksp_install_tmp, 'dummy_ksp_install_dir')
          FileUtils.mkdir(ksp_install_dir)
          pre_existing_file = File.join(ksp_install_dir, 'some_file')
          FileUtils.touch(pre_existing_file)
          run_command = [
            "PATH=\"#{tmp_path_dir}:${PATH}\"",
            "#{command} '#{ksp_install_dir}' 'dummy_ksp_install' '1.2.3'",
          ].join(' ')
          _, _, status = Open3.capture3(run_command)
          expect(status.success?).to be(true)
          expect(Dir.exist?(ksp_install_dir)).to be(true)
          expect(File.exist?(File.join(ksp_install_dir, 'readme.txt'))).to be(true)
          expect(File.exist?(pre_existing_file)).to be(false)
        end
      end
    end
  end

  it 'continues when ckan forget exits with nonzero status' do
    Dir.mktmpdir('tmp_path') do |tmp_path_dir|
      ckan_command = File.join(tmp_path_dir, 'ckan')
      Tempfile.open do |ckan_command_log|
        File.open(ckan_command, 'w') do |file|
          file.write <<~SH
            #!/usr/bin/env sh
            set -e
            echo "ckan ${@}" >> '#{ckan_command_log.path}'
          SH
        end
        FileUtils.chmod '+x', ckan_command

        Dir.mktmpdir('ksp_install_tmp') do |ksp_install_tmp|
          ksp_install_dir = File.join(ksp_install_tmp, 'dummy_ksp_install_dir')
          run_command = [
            "PATH=\"#{tmp_path_dir}:${PATH}\"",
            "#{command} '#{ksp_install_dir}' 'dummy_ksp_install' '1.2.3'",
          ].join(' ')
          _, _, status = Open3.capture3(run_command)
          expect(status.success?).to be(true)
          expect(Dir.exist?(ksp_install_dir)).to be(true)
          expect(File.exist?(File.join(ksp_install_dir, 'readme.txt'))).to be(true)
        end
      end
    end
  end

  it 'prints usage when the wrong number of arguments are given' do
    _, err, status = Open3.capture3("#{command} one two")
    expect(status.success?).to be(false)
    expect(err).to eq("Usage - make-ksp-install [ksp_dir] [ksp_install_name] [ksp_version]\n")
  end
end
