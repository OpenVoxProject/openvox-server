require 'resolv'
require 'socket'

# JRuby's UDPSocket#recvfrom returns uncompressed IPv6 peer addresses
# ("2001:db8:0:0:0:0:0:1") while Addrinfo#ip_address compresses them
# ("2001:db8::1"). Resolv::DNS::Requester::UnconnectedUDP keys pending
# queries with the latter and looks replies up with the former, so with
# 2+ IPv6 nameservers in resolv.conf every reply is discarded as unsolicited
# and each lookup hangs for 160 seconds before returning an empty array.
#
# Loading this file applies a monkeypatch that restores normalization
# lost when JRuby 9.4.13.0 reverted to using the upstream Resolv gem
# instead of carrying a patched version that accounted for issues like
# this.
#
# @see https://github.com/OpenVoxProject/openvox-server/issues/535
# @see https://github.com/jruby/jruby/pull/4496
# @see https://github.com/ruby/resolv/commit/5c161804ddef0dcf3c230ae6e5b9be1185861797
module Puppet
  module Server
    module ResolvIPv6Normalization
      def recv_reply(readable_socks)
        reply, from = super
        return [reply, from] unless from.is_a?(Array) && from[0].is_a?(String)
        return [reply, from] unless from[0].include?(':')

        begin
          [reply, [Addrinfo.ip(from[0]).ip_address, from[1]]]
        rescue SocketError, ArgumentError
          [reply, from]
        end
      end
    end
  end
end

# Monkeypatch
if RUBY_ENGINE == 'jruby' && !Resolv::DNS::Requester::UnconnectedUDP.ancestors.include?(Puppet::Server::ResolvIPv6Normalization)
  Resolv::DNS::Requester::UnconnectedUDP.prepend(Puppet::Server::ResolvIPv6Normalization)
end
