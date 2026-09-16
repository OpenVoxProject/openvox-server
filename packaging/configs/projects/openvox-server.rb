project 'openvox-server' do |proj|
  platform = proj.get_platform

  fail "openvox-server does not build for platform #{platform.name}" unless platform.is_rpm? || platform.is_deb?

  proj.description 'OpenVox Server (puppetserver), the OpenVox certificate authority and catalog compilation service'
  proj.license 'Apache-2.0'
  proj.vendor 'Vox Pupuli <openvox@voxpupuli.org>'
  proj.homepage 'https://github.com/openvoxproject/openvox-server'

  if ENV['OPENVOX_SERVER_VERSION'] && !ENV['OPENVOX_SERVER_VERSION'].empty?
    proj.version ENV['OPENVOX_SERVER_VERSION']
  else
    proj.version_from_git
  end
  proj.noarch

  version = proj.get_version
  openvox_major = version.split('.').first.to_i
  os_version = platform.os_version.to_i # Note this changes Ubuntu 26.04 to just 26, for example
  proj.target_repo "openvox#{openvox_major}"
  proj.setting(:package_version, version)

  # Where the openvox-server-uberjar archives live. CI builds fetch them from
  # the public artifacts bucket where the uberjar jobs uploaded them earlier in
  # the same run. The vox:build rake task points this at packaging/output for
  # local builds.
  tarball_base = ENV['SERVER_TARBALL_BASE']
  tarball_base = "https://s3.osuosl.org/openvox-artifacts/openvox-server/#{version}" if tarball_base.to_s.empty?
  proj.setting(:server_tarball_base, tarball_base)

  # Two different service styles are used. The direct style matches the
  # ezbake 4.x packages shipped for OpenVox 9, running java straight from the
  # unit with Type=notify or notify-reload. The wrapper style matches the
  # ezbake 2.x packages shipped for OpenVox 8, where the service runs through
  # the start/stop/reload CLI wrappers.
  default_style = openvox_major >= 9 ? 'direct' : 'wrapper'
  proj.setting(:service_style, (ENV['SERVER_SERVICE_STYLE'] || default_style).to_sym)

  # Type=notify-reload needs systemd 253 or newer. Older platforms use
  # Type=notify with an explicit ExecReload.
  old_systemd = ((platform.is_fips? || platform.is_el?) && os_version <= 9) ||
                (platform.is_amazon? && os_version <= 2023) ||
                (platform.is_sles? && os_version <= 15) ||
                (platform.is_ubuntu? && platform.os_version == '22.04')
  proj.setting(:systemd_notify_reload, !old_systemd)

  # Per platform java runtime dependency. Keep this in sync with what each
  # distro actually packages.
  java_dep =
    if platform.is_fips?
      # BC-FJA 2.x is only FIPS certified through Java 21, and 1.x through 17
      openvox_major >= 9 ? 'jre-21-headless' : 'jre-17-headless'
    elsif platform.is_el?
      case [os_version, openvox_major]
      in [8 | 9, 8] then 'jre-17-headless'
      in [10, 8] then 'jre-21-headless'
      in [8, 9] then 'jre-21-headless'
      in [9 | 10, 9] then 'jre-25-headless'
      else fail "Unknown el version #{platform.os_version} for OpenVox #{openvox_major}"
      end
    elsif platform.is_fedora?
      openvox_major >= 9 ? 'jre-25-headless' : 'jre-21-headless'
    elsif platform.is_amazon?
      openvox_major >= 9 ? 'java-25-amazon-corretto-headless' : 'java-17-amazon-corretto-headless'
    elsif platform.is_sles?
      openvox_major >= 9 ? 'java-25-openjdk-headless' : 'java-17-openjdk-headless'
    elsif platform.is_deb?
      if openvox_major >= 9
        'openjdk-25-jre-headless'
      elsif platform.is_debian? && os_version <= 12
        'openjdk-17-jre-headless'
      else
        'openjdk-21-jre-headless'
      end
    else
      fail "No java dependency known for platform #{platform.name}"
    end
  # OpenVox 9 rpm packages point at the exact runtime of the required java
  # package instead of the alternatives symlink. Debian based packages keep
  # /usr/bin/java because the Debian JVM directory paths include the
  # architecture and these packages are noarch. At some point we might migrate
  # to arch-specific packages to go back to the direct path, but we'll need
  # to make that change carefully. OpenVox 8 packages keep /usr/bin/java everywhere
  # like ezbake 2.x did. A platform file can override java_bin through settings.
  java_bins = {
    'jre-21-headless' => '/usr/lib/jvm/jre-21/bin/java',
    'jre-25-headless' => '/usr/lib/jvm/jre-25/bin/java',
    'java-25-amazon-corretto-headless' => '/usr/lib/jvm/jre-25/bin/java',
    'java-25-openjdk-headless' => '/usr/lib64/jvm/jre-25/bin/java',
  }
  java_bin = openvox_major >= 9 ? java_bins.fetch(java_dep, '/usr/bin/java') : '/usr/bin/java'
  proj.setting(:java_bin, proj.settings[:java_bin] || java_bin)

  java_args = '-Xms2g -Xmx2g'
  # OpenVox 9 sets the JRuby logger in code, OpenVox 8 still needs the flag
  java_args = "#{java_args} -Djruby.logger.class=com.puppetlabs.jruby_utils.jruby.Slf4jLogger" if openvox_major < 9
  if platform.is_fips?
    java_args = "-Djava.security.properties==/opt/puppetlabs/server/data/puppetserver/java.security.fips #{java_args}"
  end
  proj.setting(:java_args, java_args)

  # JRuby needs these module flags on newer JVMs. The direct style unit passes
  # them through JAVA_ARGS_DIST so package upgrades can change them without
  # touching the user-editable defaults file, and cli-defaults.sh adds them for
  # CLI runs once the installed java is at least the given major version.
  if openvox_major >= 9
    proj.setting(:java_args_dist, '--add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED --enable-native-access=ALL-UNNAMED')
    proj.setting(:java_args_dist_min_major, 21)
  else
    proj.setting(:java_args_dist, '--add-opens java.base/sun.nio.ch=ALL-UNNAMED --add-opens java.base/java.io=ALL-UNNAMED')
    proj.setting(:java_args_dist_min_major, 17)
  end

  proj.requires java_dep
  proj.requires 'tzdata-java' if platform.is_amazon?
  proj.requires 'bash'
  proj.requires 'procps'
  proj.requires 'net-tools' if proj.settings[:service_style] == :wrapper
  proj.requires '/usr/bin/which' if platform.is_rpm?
  # The ezbake rpms carry a plain systemd requirement on the el-like platforms.
  # SLES gets %{?systemd_requires} from the vanagon spec template instead.
  proj.requires 'systemd' if platform.is_rpm? && !platform.is_sles?
  proj.requires 'adduser' if platform.is_deb?
  if openvox_major >= 9
    proj.requires 'openvox-agent', '>= 9.0.0~rc1'
  else
    proj.requires 'openvox-agent', '>= 8.29.0'
    proj.requires 'openvox-agent', '< 9.0.0~'
  end

  proj.replaces 'puppetserver'
  proj.conflicts 'puppetserver'

  proj.directory '/opt/puppetlabs/bin'
  proj.directory '/opt/puppetlabs/server/bin'
  proj.directory '/opt/puppetlabs/server/apps/puppetserver'
  proj.directory '/opt/puppetlabs/server/data/puppetserver', mode: '0770', owner: 'puppet', group: 'puppet'
  proj.directory '/opt/puppetlabs/server/data/puppetserver/jars', mode: '0700', owner: 'puppet', group: 'puppet'
  proj.directory '/opt/puppetlabs/server/data/puppetserver/yaml', mode: '0700', owner: 'puppet', group: 'puppet'
  proj.directory '/opt/puppetlabs/puppet/lib/ruby/vendor_gems'
  proj.directory '/etc/puppetlabs/puppetserver', mode: '0750', owner: 'puppet', group: 'puppet'
  proj.directory '/var/log/puppetlabs/puppetserver', mode: '0700', owner: 'puppet', group: 'puppet'
  # The direct style lets systemd manage the runtime directory
  proj.directory '/var/run/puppetlabs/puppetserver', mode: '0755', owner: 'puppet', group: 'puppet' if proj.settings[:service_style] == :wrapper

  proj.component 'uberjar-tarball'
  proj.component 'openvox-server'
end
