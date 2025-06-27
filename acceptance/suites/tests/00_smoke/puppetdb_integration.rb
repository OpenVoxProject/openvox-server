## Tests that PuppetDB can be integrated with Puppet Server in a simple
## monolithic install (i.e. PuppetDB on same node as Puppet Server).
##
## In this context 'integrated' just means that Puppet Server is able to
## communicate over HTTP/S with PuppetDB to send it information, such as
## agent run reports.
##
## This test validates communication is successful by querying the PuppetDB HTTP
## API and asserting that an updated factset, catalog and report from an agent
## run made it into PuppetDB. Additionally, the STDOUT of the agent run is
## tested for the presence of a Notify resource that was exported by another
## node.
##
## Finally, the output of the Puppet Server HTTP /status API is tested
## to ensure that metrics related to PuppetDB communication were recorded.
#

# We only run this test if we'll have puppetdb installed and
# configured, which is gated in
# acceptance/suites/pre_suite/foss/95_install_pdb.rb.
skip_test('openvoxdb was not configured on this platform due to lack of postgresql packages') if !test_with_pdb?
skip_test('Skipped for fips') if master.fips_mode?
skip_test if master.is_pe?

require 'json'
require 'time'
require 'securerandom'

run_timestamp = nil
master_fqdn = on(master, '/opt/puppetlabs/bin/facter fqdn').stdout.chomp
random_string = SecureRandom.urlsafe_base64.freeze

puppetserver_conf_path = '/etc/puppetlabs/puppetserver/conf.d/puppetserver.conf'
old_puppetserver_conf = on(master, "cat #{puppetserver_conf_path}").stdout

common_yaml_path = '/etc/puppetlabs/code/environments/production/data/common.yaml'

create_remote_file(master, common_yaml_path, <<EOM)
---
some-test-key: test-key-value
EOM

on(master, "chmod 644 #{common_yaml_path}")

step 'Configure puppetserver to track hiera lookups' do
  conf = read_tk_config_string(old_puppetserver_conf)
  conf['jruby-puppet']['track-lookups'] = true
  modify_tk_config(master, puppetserver_conf_path, conf, replace=true)
end

step 'Configure site.pp for PuppetDB' do
  sitepp = '/etc/puppetlabs/code/environments/production/manifests/site.pp'
  create_remote_file(master, sitepp, <<EOM)
node 'resource-exporter.test' {
  @@notify{'#{random_string}': }
}

lookup('some-test-key')

node '#{master_fqdn}' {
  Notify<<| title == '#{random_string}' |>>

  # Dummy query to record a hit for the PuppetDB query API to metrics.
  $_ = puppetdb_query(['from', 'nodes', ['extract', 'certname']])
}
EOM
  on(master, "chmod 644 #{sitepp}")

  teardown do
    modify_tk_config(master, puppetserver_conf_path, read_tk_config_string(old_puppetserver_conf), replace=true)
    on(master, "rm -f #{sitepp} #{common_yaml_path}")
  end
end

with_puppet_running_on(master, {}) do
  step 'Enable PuppetDB' do
    apply_manifest_on(master, <<EOM)
class{'puppetdb::master::config':
  terminus_package        => 'openvoxdb-termini',
  enable_reports          => true,
  manage_report_processor => true,
}
EOM
  end

  step 'Run agent to generate exported resources' do
    # This test compiles a catalog using a differnt certname so that
    # later runs can test collection.
    on(master, 'puppetserver ca generate --certname=resource-exporter.test')

    teardown do
      on(master, puppet('node', 'deactivate', 'resource-exporter.test'))
      on(master, "puppet ssl clean --certname resource-exporter.test")
      on(master, 'puppetserver ca clean --certname=resource-exporter.test')
    end

    on(master, puppet_agent('--test', '--noop',
                            '--certname', 'resource-exporter.test'),
              :acceptable_exit_codes => [0,2])
  end

  step 'Run agent to trigger data submission to PuppetDB' do
    # ISO 8601 timestamp, with milliseconds and time zone. Local time is used
    # instead of UTC as both PuppetDB and Puppet Server log in local time.
    run_timestamp = Time.iso8601(on(master, 'date +"%Y-%m-%dT%H:%M:%S.%3N%:z"').stdout.chomp)
    on(master, puppet_agent("--test"), :acceptable_exit_codes => [0,2]) do |result|
      assert_match(/Notice: #{random_string}/, result.stdout,
                  'Puppet run collects exported Notify')
    end
  end

  step 'Validate PuppetDB metrics captured by puppet-profiler service' do
    query = "curl -k https://localhost:8140/status/v1/services/puppet-profiler?level=debug"
    response = JSON.parse(on(master, query).stdout.chomp)
    pdb_metrics = response['status']['experimental']['puppetdb-metrics']

    # NOTE: If these tests fail, then likely someone changed a metric
    # name passed to Puppet::Util::Profiler.profile over in the Ruby
    # terminus code of the PuppetDB project without realizing that is a
    # breaking change to metrics critical for measuring compiler performance.
    [
      "query",
      "resource_search",
      "facts_find",
      "catalog_save",
      "facts_save",
      "command_submit_replace_catalog",
      "command_submit_replace_facts",
      "report_process",
      "command_submit_store_report",
      "payload_format",
      "facts_encode",
      "catalog_munge",
      "report_convert_to_wire_format_hash"
    ].each do |metric_name|
      metric_data = pdb_metrics.find {|m| m['metric'] == metric_name } || {}

      metric_count = metric_data.fetch('count', 0)
      logger.debug("PuppetDB metrics #{metric_name} recorded #{metric_count} times")
      assert_operator(metric_count, :>, 0,
                      "PuppetDB metrics recorded for: #{metric_name}")
    end
  end
end

step 'Validate PuppetDB successfully stored agent data' do
  query = "curl http://localhost:8080/pdb/query/v4/nodes/#{master_fqdn}"
  agent_datasets = %w[facts_timestamp catalog_timestamp report_timestamp]
  missing_datasets = [ ]
  retries = 3

  retries.times do |i|
    logger.debug("PuppetDB query attempt #{i} for updated agent data...")

    missing_datasets = [ ]
    response = JSON.parse(on(master, query).stdout.chomp)

    dataset_states = response.select {|k, v| agent_datasets.include?(k)}.map do |k, v|
      t = Time.iso8601(v) rescue nil
      [k, t]
    end.to_h

    missing_datasets = dataset_states.select {|k, v| v.nil? || (v < run_timestamp)}.keys
    break if missing_datasets.empty?

    sleep(1) # Give PuppetDB some time to catch up.
  end

  assert_empty(missing_datasets, <<-EOS)
PuppetDB did not return updated data for #{master_fqdn} after
#{retries} consecutive queries. The following timestamps were
missing or not updated to be later than: #{run_timestamp.iso8601(3)}:

  #{missing_datasets.join(' ')}

Check puppetserver.log for errors that may have ocurred during
data submission.

Check puppetdb.log for errors that may have ocurred during
data processing.
EOS
end

step 'Validate PuppetDB stored lookup data sent from puppetserver' do
  query = "curl -X POST http://localhost:8080/pdb/query/v4/catalog-input-contents" <<
    " -H 'Content-Type:application/json'" <<
    " -d '{\"query\": \"\" }'"

  retries = 3

  (1..(retries + 1)).each do |i|

    if i > retries
      raise "Attempted #{retries} times to get lookup data from puppetdb, but none found"
    end

    logger.debug("PuppetDB query attempt #{i} for catalog inputs")
    response = JSON.parse(on(master, query).stdout.chomp)

    # Give PuppetDB some time to process it is running slow
    if response.empty?
      sleep 1
      next
    end

    response.each do |input|
      assert_equal('some-test-key', input['name'])
      assert_equal('hiera', input['type'])
    end
    break
  end
end
