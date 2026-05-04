# OpenVox Server

[OpenVox Server](https://docs.openvoxproject.org/openvox-server/latest/services_master_puppetserver.html)
implements OpenVox's server-side components for managing
[OpenVox](https://docs.openvoxproject.org/openvox/latest/) agents in a distributed,
service-oriented architecture. OpenVox Server is built on top of the same
technologies that make [OpenVoxDB](https://docs.openvoxproject.org/openvoxdb/latest/)
successful, and which allow us to greatly improve performance, scalability,
advanced metrics collection, and fine-grained control over the Ruby runtime.

## Release notes

For information about the current and most recent versions of OpenVox Server,
see the [release notes](https://docs.openvoxproject.org/openvox-server/latest/release_notes.html).

## Installing OpenVox Server

See [Installing OpenVox Server from Packages](https://docs.openvoxproject.org/openvox-server/latest/install_from_packages.html)
for complete installation requirements and instructions.

## Ruby and OpenVox Server

OpenVox Server uses its own JRuby interpreter, which doesn't load gems or other
code from your system Ruby. If you want OpenVox Server to load additional gems,
use the OpenVox Server-specific `gem` command to install them. See [OpenVox
Server and Gems](https://docs.openvoxproject.org/openvox-server/latest/gems.html) for more
information about gems and OpenVox Server.

## Configuration

OpenVox Server honors almost all settings in `puppet.conf` and should pick them
up automatically. See the [Configuration](https://docs.openvoxproject.org/openvox-server/latest/configuration.html)
documentation for details.

For more information on the differences between OpenVox Server's support for
`puppet.conf` settings and the Ruby master's, see our documentation of
[differences in `puppet.conf`](https://docs.openvoxproject.org/openvox-server/latest/puppet_conf_setting_diffs.html).

### Certificate authority configuration

OpenVox can use its built-in certificate authority (CA) and public key
infrastructure (PKI) tools or use an existing external CA for all of its
secure socket layer (SSL) communications. See certificate authority
[docs](https://docs.openvoxproject.org/openvox-server/latest/config_file_ca.html) for details.

### SSL configuration

In network configurations that require external SSL termination, you need to do
a few things differently in OpenVox Server. See
[External SSL Termination](https://docs.openvoxproject.org/openvox-server/latest/external_ssl_termination.html)
for details.

## Command-line utilities

OpenVox Server provides several command-line utilities for development and
debugging purposes. These commands are all aware of
[`puppetserver.conf`](https://docs.openvoxproject.org/openvox-server/latest/configuration.html),
as well as the gems and Ruby code specific to OpenVox Server and OpenVox, while
keeping them isolated from your system Ruby.

For more information, see [OpenVox Server
Subcommands](https://docs.openvoxproject.org/openvox-server/latest/subcommands.html).

## Known issues

As this application is still in development, there are a few [known
issues](https://docs.openvoxproject.org/openvox-server/latest/known_issues.html)
that you should be aware of.

## Developer documentation

If you want to play with our code, these documents should prove useful:

- [Running OpenVox Server from source](https://docs.openvoxproject.org/openvox-server/latest/dev_running_from_source.html)
- [Debugging](https://docs.openvoxproject.org/openvox-server/latest/dev_debugging.html)
- [OpenVox Server subcommands](https://docs.openvoxproject.org/openvox-server/latest/subcommands.html)

OpenVox Server also uses the
[Trapperkeeper](https://github.com/OpenVoxProject/trapperkeeper) Clojure framework.

## Testing

To run lein tests, do the following:

- Clone the repo with the `--recursive` flag, or after cloning, do `git submodule init && git submodule update`
- Run `./dev-setup`
- Run `lein test`

## Branching strategy

OpenVox Server's branching strategy is documented on the [GitHub repo
wiki](https://github.com/OpenVoxProject/openvox-server/wiki/Branching-Strategy).

## Issue tracker

Have feature requests, found a bug, or want to see what issues are in flight?
Visit our [GitHub Issues](https://github.com/OpenVoxProject/openvox-server/issues).

## License

Copyright © 2013-2018 Puppet
Copyright © 2024 OpenVox Project contributors

Distributed under the [Apache License, Version
2.0](http://www.apache.org/licenses/LICENSE-2.0.html).

## Special thanks to

### Cursive Clojure

[Cursive](https://cursiveclojure.com/) is a Clojure IDE based on [IntelliJ
IDEA](http://www.jetbrains.com/idea/download/index.html). Several of us at
Puppet use it regularly and couldn't live without it. It's got some really great
editing, refactoring, and debugging features, and the author, Colin Fleming, has
been amazingly helpful and responsive when we have feedback. If you're a Clojure
developer, you should definitely check it out!

### JRuby

[JRuby](http://jruby.org/) is an implementation of the Ruby programming language
that runs on the JVM. It's a fantastic project, and the bridge that allows us to
run Puppet Ruby code while taking advantage of the JVM's advanced features and
libraries. We're very grateful to the developers for building such a great
product and for helping us work through a few bugs that we've discovered along
the way.

## Maintenance

Tickets: [https://github.com/OpenVoxProject/openvox-server/issues](https://github.com/OpenVoxProject/openvox-server/issues)
