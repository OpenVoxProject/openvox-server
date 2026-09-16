require_relative '../../lib/server_packaging'

# Builds the puppetserver uberjar and the vendored gems once, as a rooted
# archive that the openvox-server project unpacks on every platform. The
# regular variant builds on el-9 and the FIPS variant on redhatfips-9, see
# ServerPackaging::UBERJAR_PLATFORMS.
project 'openvox-server-uberjar' do |proj|
  platform = proj.get_platform
  variant = ServerPackaging.uberjar_variant(platform.name)
  build_platform = ServerPackaging::UBERJAR_PLATFORMS.fetch(variant)
  unless platform.name == build_platform
    fail "The #{variant} variant of openvox-server-uberjar builds on #{build_platform}, not #{platform.name}"
  end

  proj.description 'OpenVox Server uberjar and vendored gems'
  proj.license 'Apache-2.0'
  proj.vendor 'Vox Pupuli <openvox@voxpupuli.org>'
  proj.homepage 'https://github.com/openvoxproject/openvox-server'

  if ENV['OPENVOX_SERVER_VERSION'] && !ENV['OPENVOX_SERVER_VERSION'].empty?
    proj.version ENV['OPENVOX_SERVER_VERSION']
  else
    proj.version_from_git
  end
  version = proj.get_version
  major = version.split('.').first.to_i
  proj.setting(:package_version, version)

  # The output is the archive of the installed tree, not a package
  proj.generate_packages false
  proj.generate_archives true

  # OpenVox 8 is built with JDK 17 and OpenVox 9 with JDK 21
  proj.setting(:build_jdk, major >= 9 ? 'java-21-openjdk-headless' : 'java-17-openjdk-headless')
  proj.setting(:uberjar_profiles, variant == 'fips' ? 'user,pkg-fips,provided' : 'user,pkg,provided')

  proj.setting(:lein_version, '2.13.0')
  proj.setting(:lein_script_sha256, '61cf3a0786748238bc7d78e24b77a875d8c4c0704c3bc11f7180e979b46bcc2c')
  proj.setting(:lein_jar_sha256, '5f5231f06c3c7924e3241e3dfa52885577fb44ddf8a9ea373d2c5e2f27217565')

  # Everything the component installs below these directories ends up in the archive
  proj.directory '/opt/puppetlabs/server/apps/puppetserver'
  proj.directory '/opt/puppetlabs/server/data/puppetserver'
  proj.directory '/opt/puppetlabs/puppet/lib/ruby/vendor_gems'

  proj.component 'server-uberjar'
end
