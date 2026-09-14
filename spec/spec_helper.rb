# frozen_string_literal: true

if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    skip '/spec/'
  end
end

# Loading the real puppetlabs-onceover CLI entrypoint mirrors how this
# plugin is actually loaded in production: `bin/puppetlabs-onceover`
# requires 'puppetlabs-onceover/cli', which -- after defining
# PuppetlabsOnceover::CLI::Run and friends -- requires
# lib/puppetlabs-onceover/cli/plugins.rb, which globs every installed
# `puppetlabs-onceover-*` gem (including this one, since it's installed via
# the local gemspec/Bundler path source) and requires it. That's what
# actually loads our own lib/puppetlabs-onceover/octocatalog-diff.rb.
#
# This ordering matters: our own cli.rb reopens PuppetlabsOnceover::CLI::Run
# and calls `.command.add_command` on it at require time, so that
# constant/method must already exist first. Requiring
# 'puppetlabs-onceover/cli/run' directly (instead of the top-level
# 'puppetlabs-onceover/cli') does NOT work here: run.rb's own first line is
# `require 'puppetlabs-onceover/cli'`, and cli.rb's last line is
# `require 'puppetlabs-onceover/cli/run'` -- so entering via cli/run first
# creates a require cycle where Ruby's circular-require guard causes
# `class Run; def self.command; end; end` to never actually run before
# cli/plugins.rb (reached via cli.rb) tries to load our plugin and call it.
require 'puppetlabs-onceover/cli'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.order = :random
  Kernel.srand config.seed

  # `PuppetlabsOnceover::Logger` is mixed into `Object` (see the real gem's
  # lib/puppetlabs-onceover/logger.rb), so every object -- including our spec
  # doubles and the CLI command's `self` -- gets a `#logger` method that logs
  # to real STDOUT via the `logging` gem. Silence it so spec runs (and the
  # $stdout-capturing helpers in cli_spec.rb) aren't full of debug noise.
  config.before(:suite) do
    logger.level = :fatal
  end
end
