test_name 'Validate puppetserver systemd unit Type for platform'

skip_test 'No primary node to validate puppetserver service type on' unless master

variant, version, _, _ = master['platform'].to_array
platform = "#{variant}-#{version}"

# Beaker normalizes the RHEL-family guests to el-* platform names.
# These legacy OpenVox 9.x acceptance OSes still use Type=forking.
forking_platforms = %w[
  el-8
  el-9
  ubuntu-2204
].freeze

expected_type = forking_platforms.include?(platform) ? 'forking' : 'notify-reload'

step "Validate Type= for #{platform} (expected #{expected_type})" do
  on(master, 'systemctl cat puppetserver.service')

  type_result = on(master, 'systemctl show --property Type --value puppetserver.service')
  actual_type = type_result.stdout.strip

  assert_equal(expected_type, actual_type, "Unexpected systemd service Type for #{platform}. Expected #{expected_type}, got #{actual_type}")
end
