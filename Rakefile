# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

task :default => :spec
task :test => %i[rubocop spec]

begin
  require 'rubygems'
  require 'github_changelog_generator/task'
rescue LoadError
  # Do nothing if no required gem installed
else
  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    config.exclude_labels = %w[duplicate question invalid wontfix wont-fix skip-changelog github_actions]
    config.user = 'puppetlabs'
    config.project = 'puppetlabs-onceover-octocatalog-diff'
    gem_version = Gem::Specification.load("#{config.project}.gemspec").version
    config.future_release = "v#{gem_version}"
  end
end
