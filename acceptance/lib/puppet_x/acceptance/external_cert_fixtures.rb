module PuppetX
module Acceptance
class ExternalCertFixtures
  attr_reader :fixture_dir
  attr_reader :test_dir
  attr_reader :master_name
  attr_reader :agent_name

  ##
  # ExternalCerts provides a utility class to fill in fixture data and other
  # large blobs of text configuration for the acceptance testing of External CA
  # behavior.
  #
  # @param [String] fixture_dir The fixture directory to read from.
  #
  # @param [String] test_dir The directory on the remote system, used for
  # filling in templates.
  #
  # @param [String] master_name The common name the master should be reachable
  #   at.  This name should match up with the certificate files in the fixture
  #   directory, e.g. master1.example.org.
  #
  # @param [String] agent_name The common name the agent is configured to use.
  #   This name should match up with the certificate files in the fixture
  #   directory, e.g.
  def initialize(fixture_dir, test_dir, master_name = "master1.example.org", agent_name = "agent1.example.org")
    @fixture_dir = fixture_dir
    @test_dir = test_dir
    @master_name = master_name
    @agent_name = agent_name
  end

  def master_short_name
    @master_short_name ||= master_name.gsub(/\..*/, '')
  end

  def host_entry
    @host_entry ||= "127.0.0.3 #{master_name} #{master_short_name} puppet"
  end

  def root_ca_cert
    @root_ca_cert ||= File.read(File.join(fixture_dir, 'root', 'ca-root.crt'))
  end

  def agent_ca_cert
    @agent_ca_cert ||= File.read(File.join(fixture_dir, 'agent-ca', 'ca-agent-ca.crt'))
  end

  def master_ca_cert
    @master_ca_cert ||= File.read(File.join(fixture_dir, 'master-ca', 'ca-master-ca.crt'))
  end

  def master_ca_crl
    @master_ca_crl ||= File.read(File.join(fixture_dir, 'master-ca', 'ca-master-ca.crl'))
  end

  def agent_cert
    @agent_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.issued_by.agent-ca.crt"))
  end

  def agent_key
    @agent_key ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.issued_by.agent-ca.key"))
  end

  def agent_email_cert
    @agent_email_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.email.issued_by.agent-ca.crt"))
  end

  def agent_email_key
    @agent_email_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{agent_name}.email.issued_by.agent-ca.key"))
  end

  def master_cert
    @master_cert ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.master-ca.crt"))
  end

  def master_key
    @master_key ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.master-ca.key"))
  end

  def master_cert_rogue
    @master_cert_rogue ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.agent-ca.crt"))
  end

  def master_key_rogue
    @master_key_rogue ||= File.read(File.join(fixture_dir, 'leaves', "#{master_name}.issued_by.agent-ca.key"))
  end

  ## Configuration files
  def agent_conf
    @agent_conf ||= <<-EO_AGENT_CONF
[main]
color = false
certname = #{agent_name}
server = #{master_name}
certificate_revocation = false

# localcacert must contain the Root CA certificate to complete the 2 level CA
# chain when an intermediate CA certificate is being used.  Either the HTTP
# server must send the intermediate certificate during the handshake, or the
# agent must use the `ssl_client_ca_auth` setting to provide the client
# certificate.
localcacert = #{test_dir}/ca_root.crt
EO_AGENT_CONF
  end

  def agent_conf_email
    @agent_conf ||= <<-EO_AGENT_CONF
[main]
color = false
certname = #{agent_name}
server = #{master_name}
certificate_revocation = false
hostcert = #{test_dir}/agent_email.crt
hostkey = #{test_dir}/agent_email.key
localcacert = #{test_dir}/ca_root.crt
EO_AGENT_CONF
  end

  def agent_conf_crl
    @agent_conf_crl ||= <<-EO_AGENT_CONF
[main]
certname = #{agent_name}
server = #{master_name}

# localcacert must contain the Root CA certificate to complete the 2 level CA
# chain when an intermediate CA certificate is being used.  Either the HTTP
# server must send the intermediate certificate during the handshake, or the
# agent must use the `ssl_client_ca_auth` setting to provide the client
# certificate.
localcacert = #{test_dir}/ca_root.crt
EO_AGENT_CONF
  end

  def master_conf
    @master_conf ||= <<-EO_MASTER_CONF
[master]
ca = false
certname = #{master_name}
ssl_client_header = HTTP_X_CLIENT_DN
ssl_client_verify_header = HTTP_X_CLIENT_VERIFY
EO_MASTER_CONF
  end

  ##
  # Passenger Rack compliant config.ru which is responsible for starting the
  # Puppet master.
  def config_ru
    @config_ru ||= <<-EO_CONFIG_RU
\$0 = "master"
ARGV << "--rack"
ARGV << "--confdir=#{test_dir}/etc/master"
ARGV << "--vardir=#{test_dir}/etc/master/var"
require 'puppet/util/command_line'
run Puppet::Util::CommandLine.new.execute
EO_CONFIG_RU
  end

  ##
  # auth_conf should return auth authorization file that allows *.example.org
  # access to to the full REST API.
  def auth_conf
    @auth_conf_content ||= File.read(File.join(fixture_dir, 'auth.conf'))
  end

  ##
  # webserver.conf for a trustworthy master for use with Jetty
  def jetty_webserver_conf_for_trustworthy_master
    @jetty_webserver_conf_for_trustworthy_master ||= <<-EO_WEBSERVER_CONF
webserver: {
    client-auth: want
    ssl-host: 0.0.0.0
    ssl-port: 8140

    ssl-cert: "#{test_dir}/master.crt"
    ssl-key: "#{test_dir}/master.key"

    ssl-cert-chain: "#{test_dir}/ca_master_bundle.crt"
    ssl-ca-cert: "#{test_dir}/ca_agent_bundle.crt"
}
    EO_WEBSERVER_CONF
  end

  ##
  # webserver.conf for a rogue master for use with Jetty
  def jetty_webserver_conf_for_rogue_master
    @jetty_webserver_conf_for_rogue_master ||= <<-EO_WEBSERVER_CONF
webserver: {
    client-auth: want
    ssl-host: 0.0.0.0
    ssl-port: 8140

    ssl-cert: "#{test_dir}/master_rogue.crt"
    ssl-key: "#{test_dir}/master_rogue.key"

    ssl-cert-chain: "#{test_dir}/ca_agent_bundle.crt"
    ssl-ca-cert: "#{test_dir}/ca_agent_bundle.crt"
}
    EO_WEBSERVER_CONF
  end

end
end
end
