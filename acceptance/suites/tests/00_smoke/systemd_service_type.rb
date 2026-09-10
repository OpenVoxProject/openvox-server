test_name 'Validate puppetserver systemd unit Type for platform'

skip_test 'No primary node to validate puppetserver service type on' unless master

variant, version, _, _ = master['platform'].to_array
platform = "#{variant}-#{version}"

puppetserver_version = on(master, '/opt/puppetlabs/server/bin/puppetserver --version').stdout.strip
puppetserver_major_version = puppetserver_version.match(/\Apuppetserver version: (\d+)\./i)[1].to_i

# Beaker normalizes the RHEL-family guests to el-* platform names.
# These legacy OpenVox 9.x acceptance OSes still use Type=notify.
notify_platforms = %w[
  el-8
  el-9
  ubuntu-2204
].freeze

expected_type = if puppetserver_major_version == 8
  'forking'
else
  notify_platforms.include?(platform) ? 'notify' : 'notify-reload'
end

step "Validate Type= for #{platform} with puppetserver #{puppetserver_version} (expected #{expected_type})" do
  on(master, 'systemctl cat puppetserver.service')

  type_result = on(master, 'systemctl show --property Type --value puppetserver.service')
  actual_type = type_result.stdout.strip

  assert_equal(expected_type, actual_type, "Unexpected systemd service Type for #{platform}. Expected #{expected_type}, got #{actual_type}")
end
