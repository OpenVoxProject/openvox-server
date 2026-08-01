## This is a "dummy" AuthProvider that OpenVox Server registers with core
## OpenVox for cases where OpenVox Server decides that it should be in charge of
## authorizing requests at the Clojure / Ring handler level - depending upon
## the configuration of the 'use_legacy_auth_conf' setting - and not core
## OpenVox.

class Puppet::Server::AuthProvider
  def initialize(rights)
  end

  def check_authorization(method, path, params)
  end
end
