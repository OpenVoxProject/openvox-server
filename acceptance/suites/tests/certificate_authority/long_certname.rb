# Regression test: the CA must sign a certificate whose Subject CN exceeds the
# RFC 5280 ub-common-name (64) limit, and must copy that CN into a Subject
# Alternative Name (dNSName). Guards against changes in OpenSSL and BouncyCastle
# behavior (e.g. the bc-java 1.85 release).

test_name 'CA signs an agent cert with a CN over 64 chars and copies the CN to a SAN' do
  test_agent = (agents - [master]).first
  skip_test 'requires an agent not running on the CA' unless test_agent

  long_certname = 'puppet-cns.are-usually-fqdns.which-can-be-longer-than-rfc5280-allows.test'

  cadir       = puppet_config(master, 'cadir', section: 'server')
  signed_cert = "#{cadir}/signed/#{long_certname}.pem"

  teardown do
    on(master, "puppetserver ca clean --certname=#{long_certname}")
    on(test_agent, puppet("ssl clean --certname=#{long_certname}"))
  end

  step 'Agent submits a CSR with a certname longer than 64 characters' do
    on(test_agent, puppet("ssl submit_request --certname=#{long_certname}"))
  end

  step 'CA signs the long-CN certificate request' do
    on(master, "puppetserver ca sign --certname=#{long_certname}")
  end

  step 'Issued cert carries the full long CN in the Subject and in a SAN dNSName' do
    on(master, "test -f #{signed_cert}") # fails the test with a clear command if absent

    cert = encode_cert(master, signed_cert)

    cn = cert.subject.to_a.find { |name, _value, _type| name == 'CN' }&.at(1)
    assert_equal(long_certname, cn,
                 'issued cert Subject CN should be the full (>64 char) certname')

    san = cert.extensions.find { |ext| ext.oid == 'subjectAltName' }
    assert(san, 'issued cert should carry a subjectAltName extension')
    assert_match(/DNS:#{Regexp.escape(long_certname)}/, san.value,
                 'the CN should be copied into a SAN dNSName')
  end

  step 'Agent completes a run using its long-CN certificate' do
    # End-to-end: agent uses the freshly signed long-CN cert to establish TLS
    # and fetch a catalog, exercising SAN-based hostname verification.
    on(test_agent,
       puppet("agent --test --certname #{long_certname} --server #{master}"),
       :acceptable_exit_codes => [0, 2])
  end
end
