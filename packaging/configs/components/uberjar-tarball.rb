require_relative '../../lib/server_packaging'

# Fetches the archive built by the openvox-server-uberjar project and unpacks
# it into place. It carries the uberjar, the vendored gems, and on FIPS
# platforms the BouncyCastle FIPS jars. Everything else in the package is
# authored content installed by the openvox-server component.
component 'uberjar-tarball' do |pkg, settings, platform|
  variant = ServerPackaging.uberjar_variant(platform.name)
  tarball_name = ServerPackaging.uberjar_archive_name(settings[:package_version], variant)

  pkg.url File.join(settings[:server_tarball_base], tarball_name)
  pkg.sha1sum File.join(settings[:server_tarball_base], "#{tarball_name}.sha1")
  pkg.version settings[:package_version]
  pkg.install_only true

  pkg.install do
    ["gunzip -c #{tarball_name} | #{platform.tar} -C / -xf -"]
  end
end
