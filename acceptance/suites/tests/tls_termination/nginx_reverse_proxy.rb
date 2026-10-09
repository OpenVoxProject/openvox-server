require 'erb'

# Verify that agents work when TLS is terminated by an nginx reverse proxy in
# front of OpenVox Server, as described on the "External SSL Termination" docs
# page:
#   - OpenVox Server listens on plain HTTP on the loopback interface
#   - authorization.allow-header-cert-info is enabled in auth.conf
#   - nginx listens on 8140, verifies agent certificates against the CA, and
#     passes the result in the X-Client-Verify / X-Client-DN / X-Client-Cert
#     headers
#
# Covered:
#   - an existing agent gets a catalog through the proxy and the server sees it
#     as an authenticated node with the right certname (trusted facts)
#   - a node with no certificate can bootstrap one through the proxy
#     (ssl_verify_client optional), and `puppetserver ca sign` works through it
#   - forged X-Client-* headers sent through the proxy are overwritten, so a
#     client without a certificate cannot impersonate a node; the same request
#     on the server's HTTP port succeeds, which is why that port must stay on
#     the loopback interface
#   - a revoked certificate is rejected by nginx once it has reloaded the CRL
test_name "Agents work through an nginx reverse proxy that terminates TLS" do

confine :except, :platform => 'windows'
confine :except, :type => 'pe'

tag 'audit:medium',
    'audit:integration',
    'server'

fqdn        = on(master, 'facter fqdn').stdout.strip
proxy_port  = 8140
server_port = 8141

confdir       = master['puppetserver-confdir']
webserver_cfg = "#{confdir}/webserver.conf"
auth_cfg      = "#{confdir}/auth.conf"
nginx_cfg     = '/etc/nginx/conf.d/openvoxserver-tls-termination.conf'
default_auth_conf = File.expand_path('../../../../ezbake/config/conf.d/auth.conf', __dir__)

hostcert    = master.puppet['hostcert']
hostprivkey = master.puppet['hostprivkey']
cadir       = master.puppet['cadir']
cacert      = "#{cadir}/ca_crt.pem"
cacrl       = "#{cadir}/ca_crl.pem"

bootstrap_certname = 'tls-termination-bootstrap.test'
bootstrap_host     = agents.find { |a| not_controller(a) } || master
bootstrap_dir      = bootstrap_host.tmpdir('tls_termination')
# --noop: the node only needs to get a catalog and print its trusted facts; it
# must not apply whatever the production environment classifies it with.
bootstrap_agent    = "agent --test --noop --waitforcert 0 --server #{fqdn} " \
                     "--certname #{bootstrap_certname} " \
                     "--confdir #{bootstrap_dir} --vardir #{bootstrap_dir}/var"

backupdir = master.tmpdir('tls_termination_backup')

# The bootstrap steps rely on the certificate request waiting for a manual
# `puppetserver ca sign`, so turn autosign off for the test on a server that
# has it on, and put it back afterwards.
autosign_was_set = on(master, 'puppet config print autosign --section server').stdout.strip
autosign_explicit = on(master, "grep -Eq '^\\s*autosign\\s*=' #{master.puppet['config']}",
                       :acceptable_exit_codes => [0, 1]).exit_code == 0

# The notify that proves the server saw the agent's certificate goes into the
# site.pp of every environment an agent uses (production for the bootstrap
# node below), appended so an existing site.pp keeps working.
environments = (agents.map { |a| a.puppet['environment'] } + ['production']).compact.uniq
site_pps = environments.map { |env| "/etc/puppetlabs/code/environments/#{env}/manifests/site.pp" }
existing_site_pps = site_pps.select do |path|
  on(master, "test -f #{path}", :acceptable_exit_codes => [0, 1]).exit_code == 0
end

# `getenforce` only exists where SELinux does. The default policy stops nginx
# (httpd_t) from binding to 8140 and from connecting to 8141, so run permissive
# for the duration of the test and put it back afterwards.
selinux_mode = on(master, 'getenforce', :acceptable_exit_codes => [0, 127]).stdout.strip

# curl_args is the URL plus any curl options it needs, e.g. "-k https://...".
def wait_for_http(host, curl_args, attempts = 60)
  attempts.times do
    result = on(host, "curl -sf -o /dev/null #{curl_args}", :acceptable_exit_codes => (0..255))
    return if result.exit_code == 0
    sleep 2
  end
  fail_test "#{curl_args} did not answer on #{host} after #{attempts * 2} seconds"
end

def restart_puppetserver(host)
  on(host, puppet_resource('service', host['puppetservice'], 'ensure=stopped'))
  on(host, puppet_resource('service', host['puppetservice'], 'ensure=running'))
end

teardown do
  step "Stop nginx and restore OpenVox Server to terminating TLS itself" do
    on(master, puppet_resource('service', 'nginx', 'ensure=stopped', 'enable=false'))
    on(master, "rm -f #{nginx_cfg}")
    on(master, "cp -p #{backupdir}/webserver.conf #{webserver_cfg}")
    on(master, "cp -p #{backupdir}/auth.conf #{auth_cfg}")
    site_pps.each_with_index do |path, i|
      if existing_site_pps.include?(path)
        on(master, "cp -p #{backupdir}/site.pp.#{i} #{path}")
      else
        on(master, "rm -f #{path}")
      end
    end
    on(master, "setenforce 1") if selinux_mode == 'Enforcing'
    if autosign_explicit
      on(master, "puppet config set autosign #{autosign_was_set} --section server")
    else
      on(master, 'puppet config delete autosign --section server', :acceptable_exit_codes => [0, 1])
    end
    restart_puppetserver(master)
    wait_for_http(master, "-k https://127.0.0.1:#{proxy_port}/status/v1/simple")
    on(master, "puppetserver ca clean --certname #{bootstrap_certname}",
       :acceptable_exit_codes => [0, 1, 2])
    on(bootstrap_host, "rm -rf #{bootstrap_dir}")
    on(master, "rm -rf #{backupdir}")
  end
end

step "Back up the files this test changes" do
  on(master, "cp -p #{webserver_cfg} #{backupdir}/webserver.conf")
  on(master, "cp -p #{auth_cfg} #{backupdir}/auth.conf")
  site_pps.each_with_index do |path, i|
    on(master, "cp -p #{path} #{backupdir}/site.pp.#{i}") if existing_site_pps.include?(path)
  end
end

step "Check the certificate files the proxy needs are where puppet says they are" do
  [hostcert, hostprivkey, cacert, cacrl].each do |path|
    on(master, "test -f #{path}", :acceptable_exit_codes => [0, 1]) do |result|
      fail_test "#{path} does not exist on #{master}" unless result.exit_code == 0
    end
  end
end

step "Install nginx" do
  master.install_package('nginx')
  on(master, 'setenforce 0') if selinux_mode == 'Enforcing'
end

step "Switch OpenVox Server to HTTP on the loopback interface and trust client headers" do
  create_remote_file(master, webserver_cfg, <<-WEBSERVER_CONF.gsub(/^ {4}/, ''))
    webserver: {
        access-log-config: /etc/puppetlabs/puppetserver/request-logging.xml
        host: 127.0.0.1
        port: #{server_port}
    }
  WEBSERVER_CONF
  # Start from the auth.conf the package ships rather than whatever an earlier
  # test left behind (intermediate_ca.rb leaves an allow-all rule in place),
  # so the forged-header check below exercises the default rules.
  create_remote_file(master, auth_cfg, File.read(default_auth_conf))
  modify_tk_config(master, auth_cfg,
                   { 'authorization' => { 'allow-header-cert-info' => true } })
  on(master, 'puppet config set autosign false --section server')
  restart_puppetserver(master)
  wait_for_http(master, "http://127.0.0.1:#{server_port}/status/v1/simple")
end

step "OpenVox Server listens only on the loopback interface" do
  # Jetty binds the IPv4 loopback as an IPv4-mapped IPv6 address, which ss
  # prints as [::ffff:127.0.0.1]:8141.
  on(master, 'ss -ltn') do |result|
    assert_match(/(\[::ffff:)?127\.0\.0\.1\]?:#{server_port}\s/, result.stdout,
                 "expected OpenVox Server to listen on 127.0.0.1:#{server_port}")
    refute_match(/(0\.0\.0\.0|\*|\[::\]):#{server_port}\s/, result.stdout,
                 "OpenVox Server must not listen on all interfaces on port #{server_port}")
  end
end

step "Configure and start nginx in front of OpenVox Server" do
  template = File.read(File.join(__dir__, 'fixtures', 'nginx-openvoxserver.conf.erb'))
  create_remote_file(master, nginx_cfg, ERB.new(template).result(binding))
  on(master, 'nginx -t')
  on(master, puppet_resource('service', 'nginx', 'ensure=running'))
  wait_for_http(master, "-k https://127.0.0.1:#{proxy_port}/status/v1/simple")
end

step "Print the trusted facts in every catalog" do
  create_remote_file(master, "#{backupdir}/notify.pp", <<-NOTIFY_PP.gsub(/^ {4}/, ''))

    notify { "tls-termination certname=${trusted['certname']} authenticated=${trusted['authenticated']}": }
  NOTIFY_PP
  site_pps.each do |path|
    on(master, "mkdir -p #{File.dirname(path)} && cat #{backupdir}/notify.pp >> #{path}")
  end
end

step "Existing agents get a catalog through the proxy and are seen as authenticated" do
  agents.each do |agent|
    certname = agent.puppet['certname']
    on(agent, puppet('agent --test'), :acceptable_exit_codes => [0, 2]) do |result|
      assert_match(/tls-termination certname=#{Regexp.escape(certname)} authenticated=remote/,
                   result.stdout,
                   "the server did not see #{certname} as an authenticated node through the proxy")
    end
  end
end

step "A node without a certificate submits its request through the proxy" do
  on(bootstrap_host, puppet(bootstrap_agent), :acceptable_exit_codes => [1]) do |result|
    assert_match(/has not been signed yet|waitforcert setting is set to 0/i, result.stdout + result.stderr,
                 "expected the first run to stop at an unsigned certificate request")
  end
  on(master, 'puppetserver ca list') do |result|
    assert_match(/#{Regexp.escape(bootstrap_certname)}/, result.stdout,
                 "the certificate request did not reach the CA through the proxy")
  end
end

step "Sign the request through the proxy and the node gets a catalog" do
  on(master, "puppetserver ca sign --certname #{bootstrap_certname}")
  on(bootstrap_host, puppet(bootstrap_agent), :acceptable_exit_codes => [0, 2]) do |result|
    assert_match(/tls-termination certname=#{Regexp.escape(bootstrap_certname)} authenticated=remote/,
                 result.stdout)
  end
end

step "Forged client headers are overwritten by the proxy but honoured on the server port" do
  victim = bootstrap_certname
  forged = "-H 'X-Client-Verify: SUCCESS' -H 'X-Client-DN: CN=#{victim}'"
  catalog_path = "/puppet/v3/catalog/#{victim}?environment=production"

  on(bootstrap_host, "curl -sk -o /dev/null -w '%{http_code}' #{forged} " \
                     "https://#{fqdn}:#{proxy_port}#{catalog_path}") do |result|
    assert_equal('403', result.stdout.strip,
                 "a client without a certificate must not get a catalog through the proxy")
  end
  on(master, "curl -s -o /dev/null -w '%{http_code}' #{forged} " \
             "http://127.0.0.1:#{server_port}#{catalog_path}") do |result|
    assert_equal('200', result.stdout.strip,
                 "with allow-header-cert-info the server trusts the headers it is given, " \
                 "which is why its HTTP port must only be reachable by the proxy")
  end
end

step "A revoked certificate is rejected once nginx reloads the CRL" do
  on(master, "puppetserver ca revoke --certname #{bootstrap_certname}")
  on(master, 'nginx -s reload')
  on(bootstrap_host, puppet(bootstrap_agent), :acceptable_exit_codes => [1]) do |result|
    assert_match(/400/, result.stdout + result.stderr,
                 "expected nginx to reject the revoked certificate with HTTP 400")
  end
end

end
