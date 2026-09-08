# frozen_string_literal: true

# For puppetcore, set GEM_SOURCE_PUPPETCORE = 'https://rubygems-puppetcore.puppet.com'
gemsource_default = ENV['GEM_SOURCE'] || 'https://rubygems.org'
gemsource_puppetcore = if ENV['GEM_SOURCE']
                         gemsource_default
                       elsif ENV['PUPPET_FORGE_TOKEN']
                         'https://rubygems-puppetcore.puppet.com'
                       else
                         ENV['GEM_SOURCE_PUPPETCORE'] || gemsource_default
                       end
source gemsource_default

# Specify your gem's dependencies in puppetlabs-onceover-octocatalog-diff.gemspec
gemspec

# Route through gemsource_puppetcore so CI can resolve puppet ~> 9.0 from the
# private Puppetcore registry (public rubygems.org tops out at puppet 8.10.0).
# When PUPPET_FORGE_TOKEN is unset (e.g. fork PRs, local dev without a token),
# gemsource_puppetcore falls through to gemsource_default (public rubygems.org)
# and no auth is attempted against Puppetcore.
gem 'puppet', ENV['PUPPET_GEM_VERSION'] || '~> 8', source: gemsource_puppetcore

# Puppet on Ruby 3.3 / 3.4 has some missing dependencies
gem 'syslog', '~> 0.3' if RUBY_VERSION >= '3.4'

# Windows platform runtime deps. The published puppet/openvox rubygems.org
# artefacts are built on Linux and guard `ffi` / `win32ole` with build-host
# platform checks, so those deps never make it into the Linux-published
# artefact. Ruby 3.4+ removed win32ole from default gems, making the missing
# declaration fatal at require-time on Windows. Declaring them here in the
# Gemfile is evaluated on the install host at bundle time, so bundler pulls
# them on Windows only.
platforms :mingw, :x64_mingw, :mswin do
  gem 'ffi', '>= 1.15.5', '< 1.17.0', '!= 1.16.0', '!= 1.16.1', '!= 1.16.2'
  gem 'win32ole', '>= 1.8', '< 2.0'
end
