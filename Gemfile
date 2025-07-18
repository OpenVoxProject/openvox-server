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

gem 'public_suffix', '>= 4.0.7', '< 7'
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

  # docker-api 1.32.0 requires ruby 2.0.0
  gem 'docker-api', '1.31.0'
end
