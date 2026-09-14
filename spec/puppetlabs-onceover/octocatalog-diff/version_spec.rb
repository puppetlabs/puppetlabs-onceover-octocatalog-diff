# frozen_string_literal: true

require 'spec_helper'

# NOTE: on coverage -- lib/puppetlabs-onceover/octocatalog-diff/version.rb will
# never show up in the SimpleCov report at all, covered or not. Bundler
# itself requires this file very early (to evaluate `spec.version` while
# parsing puppetlabs-onceover-octocatalog-diff.gemspec from this Gemfile's
# `gemspec` line), which happens before `bundle exec rspec` even reaches
# spec_helper.rb's `SimpleCov.start`. Ruby's `require` is idempotent, so by
# the time our own lib code re-requires this file, it's a no-op and
# Ruby's Coverage module -- which SimpleCov relies on, and which can only
# instrument code executed *after* it starts -- never got a chance to see
# it execute. This spec still exercises the constant directly; it's purely
# a reporting-tool limitation, not a testing gap.
RSpec.describe PuppetlabsOnceover::Octocatalog::Diff do
  describe 'VERSION' do
    subject(:version) { described_class::VERSION }

    it 'is a String' do
      expect(version).to be_a(String)
    end

    # Deliberately not asserting on the literal current value: a past bug in
    # this program hardcoded the literal version string in a version spec,
    # which then broke on every release-prep run that bumped the version.
    # Asserting the shape instead keeps this spec stable across releases.
    it 'matches semantic-version-ish MAJOR.MINOR.PATCH formatting' do
      expect(version).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end
end
