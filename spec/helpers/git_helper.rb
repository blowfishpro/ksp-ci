# frozen_string_literal: true

require 'open3'

module GitHelper
  def in_git_dir(dir_name = 'tmp_working_dir', commits: 1, tag: nil, commits_since_tag: 0)
    Dir.mktmpdir(dir_name) do |dir|
      Dir.chdir(dir) do
        git_command = [
          'git init',
          'git config user.name test',
          'git config user.email test@example.com',
          Array.new(commits) { |index| "git commit --allow-empty -m 'commit #{index}'" },
          tag.nil? ? nil : "git tag '#{tag}'",
          Array.new(commits_since_tag) { |index| "git commit --allow-empty -m 'later commit #{index}'" },
        ].flatten.compact.join(" &&\n")
        _, status = Open3.capture2 git_command
        raise "git command exited with status #{status.exitstatus}" unless status.success?

        yield dir
      end
    end
  end
end

RSpec.configure do |config|
  config.include GitHelper
end
