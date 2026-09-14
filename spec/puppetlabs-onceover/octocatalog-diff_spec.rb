# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'puppetlabs-onceover/octocatalog-diff' do
  it 'requires cleanly' do
    expect { require 'puppetlabs-onceover/octocatalog-diff' }.not_to raise_error
  end

  it 'defines the PuppetlabsOnceover namespace' do
    expect(defined?(PuppetlabsOnceover)).to eq('constant')
  end

  it 'defines the PuppetlabsOnceover::Octocatalog namespace' do
    expect(defined?(PuppetlabsOnceover::Octocatalog)).to eq('constant')
  end

  it 'defines the PuppetlabsOnceover::Octocatalog::Diff namespace' do
    # octocatalog-diff.rb itself only declares this module; it is a
    # namespace holder for version.rb's VERSION constant (required by the
    # same file) and does not add any behavior of its own.
    expect(PuppetlabsOnceover::Octocatalog::Diff).to be_a(Module)
    expect(PuppetlabsOnceover::Octocatalog::Diff.constants).to eq([:VERSION])
  end
end
