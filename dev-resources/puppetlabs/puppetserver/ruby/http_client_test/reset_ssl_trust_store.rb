# frozen_string_literal: true

# http_client_test.clj loads this into the scripting container that its tests
# share.

# Undoes what a test with the ssl_trust_store setting leaves behind: the
# setting, the SSL context built from it and the HTTP client that uses it.
def reset_ssl_trust_store
  Puppet[:ssl_trust_store] = nil
  Puppet::Server::Config.instance_variable_set(:@puppet_and_system_ssl_context, nil)
  Puppet::Server::HttpClient.instance_variable_get(:@client_with_system_certs)&.close
  Puppet::Server::HttpClient.instance_variable_set(:@client_with_system_certs, nil)
end
