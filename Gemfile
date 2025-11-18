source ENV['GEM_SOURCE'] || 'https://rubygems.org'

def location_for(place, fake_version = nil)
  if place.is_a?(String) && place =~ /^(git[:@][^#]*)#(.*)/
    [fake_version, { :git => $1, :branch => $2, :require => false }].compact
  elsif place.is_a?(String) && place =~ /^file:\/\/(.*)/
    ['>= 0', { :path => File.expand_path($1), :require => false }]
  else
    [place, { :require => false }]
  end
end

gem 'public_suffix', '>= 4.0.7', '< 8'
# 1.0.0 is the first OpenVoxProject release
gem 'packaging', '~> 1.0', github: 'OpenVoxProject/packaging'
gem 'rake', :group => [:development, :test]

group :test do
  gem 'rspec'
  gem 'beaker', *location_for(ENV['BEAKER_VERSION'] || '~> 6.0')
  gem "beaker-hostgenerator", *location_for(ENV['BEAKER_HOSTGENERATOR_VERSION'] || "~> 2.4")
  gem "beaker-abs", *location_for(ENV['BEAKER_ABS_VERSION'] || "~> 1.0")
  gem "beaker-vmpooler", *location_for(ENV['BEAKER_VMPOOLER_VERSION'] || "~> 1.3")
  gem "beaker-puppet", *location_for(ENV['BEAKER_PUPPET_VERSION'] || "~> 4.0")
  gem 'uuidtools'
  gem 'httparty'
  gem 'master_manipulator'

  gem 'docker-api', '>=1.31.0', '< 3'
end

group :release, optional: true do
  # usually we pin to  ~> 2.1, but some of the EoL beaker 6 dependencies require ancient faraday versions
  # it's all a huge pain and the beaker setup needs to be reworked
  gem 'faraday-retry', '< 3', require: false
  gem 'github_changelog_generator', '~> 1.16.4', require: false
end
