# frozen_string_literal: true

require 'open3'

git_tag, status = Open3.capture2('git describe --tags --dirty')
raise 'Could not get version from git' unless status.success?

git_version = git_tag.delete_prefix('v').strip

Gem::Specification.new do |s|
  s.name = 'ksp-ci'
  s.version = git_version.strip
  s.summary = 'A set of tools to enable continuous integration for Kerbal Space Program mods'
  s.authors = ['https://github.com/blowfishpro']
  s.files = ['CODE_OF_CONDUCT.md', 'LICENSE', 'README.md'] + Dir.glob('lib/**/*')
  s.executables = Dir.children('bin')
  s.homepage = 'https://github.com/blowfishpro/ksp-ci'
  s.license = 'MIT'
  s.metadata['allowed_push_host'] = 'https://rubygems.pkg.github.com/blowfishpro'

  s.add_runtime_dependency 'immutable-struct', '~> 2.4'
  s.add_runtime_dependency 'kramdown', '~> 2.1'
  s.add_runtime_dependency 'rest-client', '~> 2.1'
end
