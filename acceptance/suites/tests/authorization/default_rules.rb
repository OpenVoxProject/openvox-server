## These test the new trapperkeeper-authorization auth.conf default rules
## as they're specified in FOSS puppet server.
## The tests are written to assert the curl request was "not forbidden" rather
## than expecting something meaningful from the endpoint. We're just trying to
## test that authorization is allowing & rejecting requests as expected.
##
## The testing pattern is to call one of the two curl functions with a path,
## and then one of the two assertion functions to validate allowed/denied.
## The assertion functions look for regexes and status codes in the stdout
## of the previous curl invocation.

test_name 'Default auth.conf rules'

step 'Turn on new auth support' do
  modify_tk_config(master, options['puppetserver-config'],
                   {'jruby-puppet' => {'use-legacy-auth-conf' => false}})
end

def curl_authenticated(path, &block)
  curl = 'curl '
  curl += '--cert $(puppet config print hostcert) '
  curl += '--key $(puppet config print hostprivkey) '
  curl += '--cacert $(puppet config print localcacert) '
  curl += "--write-out '\\nSTATUSCODE=%{http_code}\\n' "
  curl += "https://#{master}:8140#{path}"
  result = on(master, curl)
  block.call(result.stdout)
end

def curl_unauthenticated(path)
  curl = 'curl --insecure '
  curl += "--write-out '\\nSTATUSCODE=%{http_code}\\n' "
  curl += "https://#{master}:8140#{path}"
  on(master, curl)
end

# Issue a request with a certificate other than the primary's own.  The
# primary's certificate carries the pp_cli_auth extension so that its CLI
# tooling can reach administrative endpoints, which makes it unsuitable for
# testing rules that gate on that extension.  An ordinary agent certificate
# does not carry it.
def curl_with_cert(certname, path, &block)
  curl = 'curl '
  curl += "--cert $(puppet config print ssldir)/certs/#{certname}.pem "
  curl += "--key $(puppet config print ssldir)/private_keys/#{certname}.pem "
  curl += '--cacert $(puppet config print localcacert) '
  curl += "--write-out '\\nSTATUSCODE=%{http_code}\\n' "
  curl += "https://#{master}:8140#{path}"
  result = on(master, curl)
  block.call(result.stdout)
end

def assert_allowed(stdout, expected_statuscode = 200)
  refute_match(/Forbidden request/, stdout)
  assert_match(/STATUSCODE=#{expected_statuscode}/, stdout)
end

def assert_denied(stdout, expected_stdout)
  assert_match(/Forbidden request/, stdout)
  assert_match(expected_stdout, stdout)
  assert_match(/STATUSCODE=403/, stdout)
end

def report_query(node)
  curl = "/puppet/v3/report/#{node}?environment=production "
  curl += '-X PUT -H "Content-Type: application/json" '
  curl += '--data "{\"host\":\"' + node
  curl += '\",\"metrics\":{},\"logs\":[],\"resource_statuses\":{}}"'
end

# An ordinary agent certificate, used to test rules that are gated on the
# pp_cli_auth extension.  Generated once the server is up, and cleaned up in
# the teardown below.
agent_certname = 'filebucket-read-test-agent'

# 'puppetserver ca generate' refuses to run while any key file for the certname
# is still on disk, so clear them before generating as well as afterwards.  That
# keeps the test repeatable if an earlier run was interrupted before teardown.
def revoke_and_remove_cert(certname)
  on(master, "puppetserver ca clean --certname #{certname}",
     :accept_all_exit_codes => true)
  on(master, "rm -f $(puppet config print ssldir)/certs/#{certname}.pem " \
             "$(puppet config print ssldir)/private_keys/#{certname}.pem " \
             "$(puppet config print ssldir)/public_keys/#{certname}.pem",
     :accept_all_exit_codes => true)
end

teardown do
  revoke_and_remove_cert(agent_certname)
end

with_puppet_running_on(master, {}) do
  masterfqdn = on(master, '/opt/puppetlabs/bin/facter fqdn').stdout.chomp

  step 'environments endpoint' do
    curl_authenticated('/puppet/v3/environments') do |stdout|
      assert_allowed(stdout)
    end

    curl_unauthenticated('/puppet/v3/environments') do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/environments \(method :get\)/)
    end
  end

  step 'catalog endpoint' do
    curl_authenticated("/puppet/v3/catalog/#{masterfqdn}?environment=production") do |stdout|
      assert_allowed(stdout)
    end

    curl_authenticated('/puppet/v3/catalog/notme?environment=production') do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/catalog\/notme \(method :get\)/)
    end

    curl_unauthenticated("/puppet/v3/catalog/#{masterfqdn}?environment=production") do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/catalog\/#{masterfqdn} \(method :get\)/)
    end
  end

  step 'node endpoint' do
    curl_authenticated("/puppet/v3/node/#{masterfqdn}?environment=production") do |stdout|
      assert_allowed(stdout)
    end

    curl_authenticated('/puppet/v3/node/notme?environment=production') do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/node\/notme \(method :get\)/)
    end

    curl_unauthenticated("/puppet/v3/node/#{masterfqdn}?environment=production") do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/node\/#{masterfqdn} \(method :get\)/)
    end
  end

  step 'report endpoint' do
    curl_authenticated(report_query(masterfqdn)) do |stdout|
      assert_allowed(stdout)
    end

    # Nodes may submit only their own reports (allow: "$1"); submitting on
    # behalf of other nodes was a PE orchestrator capability that OpenVox
    # does not have. Note: this must not be guarded on master.is_pe? --
    # this suite's beaker options do not set a host type, and beaker's
    # default type is 'pe', which made is_pe? return true on FOSS hosts
    # and select the wrong assertion.
    curl_authenticated(report_query('notme')) do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/report\/notme \(method :put\)/)
    end

    curl_unauthenticated(report_query(masterfqdn)) do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/report\/#{masterfqdn} \(method :put\)/)
    end
  end

  step 'file_metadata endpoint' do
    # We'd actually need to install a module in order to get back a 200,
    # but we know that a 404 means we got past authorization
    curl_authenticated('/puppet/v3/file_metadata/modules/foo?environment=production') do |stdout|
      assert_allowed(stdout, 404)
    end

    curl_unauthenticated('/puppet/v3/file_metadata/modules/foo?environment=production') do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/file_metadata\/modules\/foo \(method :get\)/)
    end
  end

  step 'file_content endpoint' do
    # We'd actually need to install a module in order to get back a 200,
    # but we know that a 404 means we got past authorization
    curl_authenticated('/puppet/v3/file_content/modules/foo?environment=production') do |stdout|
      assert_allowed(stdout, 404)
    end

    curl_unauthenticated('/puppet/v3/file_content/modules/foo?environment=production') do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/file_content\/modules\/foo \(method :get\)/)
    end
  end

  step 'file_bucket_file endpoint' do
    # Well-formed sha256 checksum for content that was never stored.
    sum = 'a' * 64
    bucket_path = "/puppet/v3/file_bucket_file/sha256/#{sum}?environment=production"

    revoke_and_remove_cert(agent_certname)
    on(master, "puppetserver ca generate --certname=#{agent_certname}")

    # Agents are allowed 'head' so they can test whether content is already
    # stored before uploading it.  We'd actually need to store a file in the
    # filebucket in order to get back a 200, but we know that a 404 means we got
    # past authorization.
    curl_authenticated("#{bucket_path} --head") do |stdout|
      assert_allowed(stdout, 404)
    end

    curl_with_cert(agent_certname, "#{bucket_path} --head") do |stdout|
      assert_allowed(stdout, 404)
    end

    # Reading content back out is restricted to certificates carrying the
    # pp_cli_auth extension.  The primary's own certificate carries it, so the
    # request reaches the endpoint and is answered with a 404.
    curl_authenticated(bucket_path) do |stdout|
      assert_allowed(stdout, 404)
    end

    # An ordinary agent certificate does not carry pp_cli_auth, so reads are
    # refused even though the same certificate may store content.
    curl_with_cert(agent_certname, bucket_path) do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/file_bucket_file\/sha256\/#{sum} \(method :get\)/)
    end

    curl_unauthenticated(bucket_path) do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/file_bucket_file\/sha256\/#{sum} \(method :get\)/)
    end
  end

  step 'status service endpoint' do
    curl_unauthenticated('/status/v1/services') do |stdout|
      assert_allowed(stdout)
    end
  end

  step 'static file content endpoint' do
    # We'd actually need to perform a commit and use its code-id in order to
    # get back a 200, but we know that a 400 means we got past authorization
    curl_authenticated('/puppet/v3/static_file_content/foo/bar?environment=production') do |stdout|
      assert_allowed(stdout, 400)
    end

    curl_unauthenticated('/puppet/v3/static_file_content/foo/bar?environment=production') do |stdout|
      assert_denied(stdout, /\/puppet\/v3\/static_file_content\/foo\/bar \(method :get\)/)
    end
  end

  step 'certificate_revocation_list endpoint' do
    curl_authenticated('/puppet-ca/v1/certificate_revocation_list/ca?environment=production') do |stdout|
      assert_allowed(stdout)
    end

    curl_unauthenticated('/puppet-ca/v1/certificate_revocation_list/ca?environment=production') do |stdout|
      assert_allowed(stdout)
    end
  end

  step 'certificate endpoint' do
    curl_unauthenticated('/puppet-ca/v1/certificate/ca?environment=production') do |stdout|
      assert_allowed(stdout)
    end
  end

  step 'certificate_request endpoint' do
    # We'd actually need to store a CSR file on the server in order to get
    # back a 200, but we know that a 404 means we got past authorization
    curl_unauthenticated('/puppet-ca/v1/certificate_request/foo?environment=production') do |stdout|
      assert_allowed(stdout, 404)
    end
  end
end
