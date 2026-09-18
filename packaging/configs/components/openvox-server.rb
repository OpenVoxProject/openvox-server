require_relative '../../lib/server_packaging'

# Assembles all the package contents from the repo checkout. The compiled
# bits (uberjar, vendored gems, FIPS BC jars) come from the uberjar-tarball
# component.
component 'openvox-server' do |pkg, settings, platform|
  pkg.url 'file://resources/files'
  pkg.version settings[:package_version]

  wrapper_style = settings[:service_style] == :wrapper

  service_template = wrapper_style ? 'puppetserver-wrapper.service.erb' : 'puppetserver-direct.service.erb'
  pkg.add_source "file://resources/systemd/#{service_template}", erb: true
  pkg.add_source 'file://resources/systemd/puppetserver.sysconfig.erb', erb: true
  pkg.add_source 'file://resources/cli-defaults.sh.erb', erb: true
  pkg.add_source 'file://resources/tmpfiles.d/puppetserver.conf' if wrapper_style

  pkg.build do
    ["#{platform.sed} -i 's/@@VERSION@@/#{settings[:package_version]}/' bin/puppetserver"]
  end

  app_dir = '/opt/puppetlabs/server/apps/puppetserver'

  pkg.install_file 'bin/puppetserver', "#{app_dir}/bin/puppetserver", mode: '0755'
  pkg.link "../apps/puppetserver/bin/puppetserver", '/opt/puppetlabs/server/bin/puppetserver'
  pkg.link "../server/apps/puppetserver/bin/puppetserver", '/opt/puppetlabs/bin/puppetserver'

  cli_apps = %w[ca foreground gem irb prune ruby].map { |app| ["cli/#{app}", app] }
  # The wrapper style ships its own version of reload alongside start and stop
  cli_apps += wrapper_style ? %w[start stop reload].map { |app| ["wrapper/#{app}", app] } : [['cli/reload', 'reload']]
  cli_apps.each do |source, app|
    pkg.install_file source, "#{app_dir}/cli/apps/#{app}", mode: '0755'
  end
  pkg.install_file '../cli-defaults.sh', "#{app_dir}/cli/cli-defaults.sh", mode: '0755'
  pkg.install_file 'wrapper/helper-functions.sh', "#{app_dir}/helper-functions.sh", mode: '0755' if wrapper_style

  pkg.install_file 'system-config/services.d/bootstrap.cfg', "#{app_dir}/config/services.d/bootstrap.cfg"

  %w[auth ca global metrics puppetserver web-routes webserver].each do |conf|
    pkg.install_configfile "config/conf.d/#{conf}.conf", "/etc/puppetlabs/puppetserver/conf.d/#{conf}.conf"
  end
  pkg.install_configfile 'config/services.d/ca.cfg', '/etc/puppetlabs/puppetserver/services.d/ca.cfg'
  pkg.install_configfile 'config/logback.xml', '/etc/puppetlabs/puppetserver/logback.xml'
  pkg.install_configfile 'config/request-logging.xml', '/etc/puppetlabs/puppetserver/request-logging.xml'

  pkg.install_file 'java.security.fips', '/opt/puppetlabs/server/data/puppetserver/java.security.fips' if platform.is_fips?

  # The rendered service unit, defaults file, and cli-defaults.sh land in the
  # workdir root, one level above this component's source directory
  service_file = File.basename(service_template, '.erb')
  pkg.install_service "../#{service_file}", '../puppetserver.sysconfig', 'puppetserver'
  pkg.install_file '../puppetserver.conf', '/usr/lib/tmpfiles.d/puppetserver.conf' if wrapper_style

  # Ordering only, so the jar is unpacked before the source tarball below is assembled
  pkg.build_requires 'uberjar-tarball'

  # One platform's build also emits the tarball downstream packagers such as
  # the FreeBSD port build from. It carries the jar and the authored content
  # in the layout of the ezbake source tarball, under the top level directory
  # the port expects, and lands in output/ next to the packages.
  if platform.name == ServerPackaging::SOURCE_TARBALL_PLATFORM
    tarball_root = ServerPackaging.source_tarball_root(settings[:package_version])
    tarball_name = ServerPackaging.source_tarball_name(settings[:package_version])
    pkg.install do
      [
        "rm -rf ../#{tarball_root} && mkdir -p ../#{tarball_root}/ext/cli_defaults ../output",
        "cp #{app_dir}/puppet-server-release.jar ../#{tarball_root}/",
        "cp -r bin cli config system-config ../#{tarball_root}/ext/",
        "cp ../cli-defaults.sh ../#{tarball_root}/ext/cli_defaults/",
        "#{platform.tar} --sort=name --owner=0 --group=0 --numeric-owner --mtime=@$$SOURCE_DATE_EPOCH --clamp-mtime " \
        "-C .. -czf ../output/#{tarball_name} #{tarball_root}",
      ]
    end
  end

  # User and group creation, kept identical to what the ezbake packages did.
  # The rpm variant prefers uid and gid 52 when they are free.
  if platform.is_rpm?
    pkg.add_preinstall_action ['install', 'upgrade'],
      [<<~HERE
        getent group puppet >/dev/null || groupadd --system --force --gid 52 puppet
        if getent passwd puppet > /dev/null; then
          usermod --gid puppet --home /opt/puppetlabs/server/data/puppetserver \
          --comment "puppetserver daemon" puppet || :
        else
          useradd_options=('--system' '--gid' 'puppet' '--home' '/opt/puppetlabs/server/data/puppetserver' '--shell' "$(which nologin)" '--comment' 'puppetserver daemon')
          if ! getent passwd 52 > /dev/null; then
            useradd_options+=('--uid' '52')
          fi
          useradd "${useradd_options[@]}" puppet || :
        fi
      HERE
      ]
  else
    pkg.add_preinstall_action ['install', 'upgrade'],
      [<<~HERE
        getent group puppet > /dev/null || \
          groupadd -r puppet || :
        if getent passwd puppet > /dev/null; then
          usermod --gid puppet \
            --home /opt/puppetlabs/server/data/puppetserver \
            --comment "puppetserver daemon" puppet || :
        else
          useradd -r --gid puppet \
            --home /opt/puppetlabs/server/data/puppetserver --shell $(which nologin) \
            --comment "puppetserver daemon" puppet || :
        fi
      HERE
      ]
  end

  # Fresh install configuration, carried over from ext/ezbake.conf. The agent
  # owns the puppet.conf and ssl directories this touches.
  postinstall_commands = [
    'install --owner=puppet --group=puppet -d /opt/puppetlabs/server/data/puppetserver/jruby-gems',
    '/opt/puppetlabs/puppet/bin/puppet config set --section server vardir  /opt/puppetlabs/server/data/puppetserver',
    '/opt/puppetlabs/puppet/bin/puppet config set --section server logdir  /var/log/puppetlabs/puppetserver',
    '/opt/puppetlabs/puppet/bin/puppet config set --section server rundir  /var/run/puppetlabs/puppetserver',
    '/opt/puppetlabs/puppet/bin/puppet config set --section server pidfile /var/run/puppetlabs/puppetserver/puppetserver.pid',
    '/opt/puppetlabs/puppet/bin/puppet config set --section server codedir /etc/puppetlabs/code',
    'usermod --home /opt/puppetlabs/server/data/puppetserver puppet',
    'install --directory --owner=puppet --group=puppet --mode=775 /opt/puppetlabs/server/data',
    'install --directory /etc/puppetlabs/puppet/ssl',
    'chown -R puppet:puppet /etc/puppetlabs/puppet/ssl',
    'find /etc/puppetlabs/puppet/ssl -type d -print0 | xargs -0 chmod 770',
  ]
  if platform.is_fips?
    postinstall_commands << 'chown puppet:puppet /opt/puppetlabs/server/data/puppetserver/java.security.fips'
  end
  pkg.add_postinstall_action ['install'], postinstall_commands
end
