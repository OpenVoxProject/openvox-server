test_name 'PuppetDB setup'

skip_test('Skipped for fips') if master.fips_mode?
skip_test('No Postgresql packages available for this platform') if unsupported_postgresql_platform?(master)

mark_pdb_integration_expected

sitepp = '/etc/puppetlabs/code/environments/production/manifests/site.pp'

teardown do
  on(master, "rm -f #{sitepp}")
end

step 'Update Ubuntu 18 package repo' do
  if master.platform =~ /ubuntu-18/
    # bionic is EOL, so get postgresql from the archive
    on master, 'echo "deb https://apt-archive.postgresql.org/pub/repos/apt bionic-pgdg main" >> /etc/apt/sources.list'
    on master, 'curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -'
    on master, 'apt update'
  end
end

step 'Update EL postgresql repos' do
  # work around for testing on rhel and the repos on the image not finding the pg packages it needs
  if master.platform =~ /el-/
    major_version = master.platform.match(/el-(\d+)/)[1]

    on master, "dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-#{major_version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
    on master, "dnf -qy module disable postgresql"
  end
end

step 'Install PuppetDB module' do
  on(master, puppet('module install puppetlabs-puppetdb'))
end

if master.platform.variant == 'debian'
  master.install_package('apt-transport-https')
end

step 'Ensure PuppetDB certificates are setup' do
  # Normally the openvoxdb package automagically post-install runs
  # 'puppetdb ssl-setup', but this relies on the openvox-agent already
  # having certs generated at the time that the openvoxdb package
  # was installed. If we installed openvoxdb before running the suite
  # and before agent certs were generated, then we need this step
  # to ensure that openvoxdb now gets its certs. (If they are already
  # in place, the command should be idempotent.)
  apply_manifest_on(master, <<~EOM)
    exec { 'puppetdb-prepare-certs':
      command => '/opt/puppetlabs/bin/puppetdb ssl-setup',
      path    => '/bin:/sbin:/usr/bin',
      onlyif  => 'test -f /opt/puppetlabs/bin/puppetdb',
    }
  EOM
end

step 'Configure PuppetDB via site.pp' do
  manage_package_repo = ! master.platform.match?(/ubuntu-18/)
  create_remote_file(master, sitepp, <<SITEPP)
node default {
  class { 'puppetdb':
    puppetdb_package    => 'openvoxdb',
    manage_firewall     => false,
    manage_package_repo => #{manage_package_repo},
    postgres_version    => '14',
  }

  class { 'puppetdb::master::config':
    terminus_package        => 'openvoxdb-termini',
    manage_report_processor => true,
    enable_reports          => true,
  }
}
SITEPP

  on(master, "chmod 644 #{sitepp}")
  with_puppet_running_on(master, {}) do
    on(master, puppet_agent("--test --server #{master}"), :acceptable_exit_codes => [0,2])
  end
end
