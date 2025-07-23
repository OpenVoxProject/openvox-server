%global serverdir /opt/puppetlabs/server
# TODO use datadir variable?
%global appdir %{serverdir}/apps/puppetserver
# TODO use name variable?
%global etcdir %{_sysconfdir}/puppetlabs/puppetserver
%global service puppetserver

# TODO shebang expands /usr/bin/java
# TODO replace shebang
%global __requires_exclude_from .+/(vendor_gems|vendored-jruby-gems)/bin/.*$

Name:           openvox-server
Version:        8.9.0
Release:        1%{?dist}
Summary:        Server component for OpenVox agents
License:        Apache-2.0
URL:            https://voxpupuli.org
Source0:        https://artifacts.voxpupuli.org/%{name}/%{version}/%{name}-%{version}.tar.gz
Source1:        openvox-server.sysusers

BuildArch: noarch

%if 0%{?rhel} == 8
BuildRequires: systemd
%else
BuildRequires: systemd-rpm-macros
%endif
%{?sysusers_requires_compat}

%if 0%{?rhel} >= 10 || 0%{?fedora}
%global java jre-21-headless
%global java_bin /usr/lib/jvm/jre-21/bin/java
%elif 0%{?amzn}
# TODO: also a build requirement?
Requires: tzdata-java
%global java (java-17-amazon-corretto-headless or java-11-amazon-corretto-headless)
%else
# RPM 4 doesn't support elif
%if 0%{?sles_version}
%global java java-11-openjdk-headless
%else
%global java jre-17-headless
%global java_bin /usr/lib/jvm/jre-17/bin/java
%endif
%endif
BuildRequires: %{java}

Requires: %{java}
Requires: openvox-agent >= 8

# TODO obsolete puppetserver

%description
Server component

%prep
# inside the tarball there's still puppetserver
%setup -n puppetserver-%{version}

%build
%if 0%{?rhel} || 0%{?fedora}
sed -i 's|/usr/bin/java|%{java_bin}|' ext/redhat/puppetserver.service
%endif

%install
# TODO: this needs internet access
DESTDIR=%{buildroot} bash ext/build-scripts/install-vendored-gems.sh

install -p -D -m 0644 puppet-server-release.jar %{buildroot}%{appdir}/puppet-server-release.jar
install -p -D -m 0644 ext/system-config/services.d/bootstrap.cfg %{buildroot}%{appdir}/config/services.d/bootstrap.cfg

install -p -D -m 0644 ext/ezbake.manifest %{buildroot}%{_docdir}/%{name}/ezbake.manifest

install -p -D -m 0755 ext/bin/puppetserver %{buildroot}/opt/puppetlabs/bin/puppetserver
# TODO: should rubygem-puppetserver-ca actually ship this file?
install -p -D -m 0755 ext/cli/ca %{buildroot}%{appdir}/cli/apps/ca
install -p -D -m 0755 ext/cli/irb %{buildroot}%{appdir}/cli/apps/irb
install -p -D -m 0755 ext/cli/gem %{buildroot}%{appdir}/cli/apps/gem
install -p -D -m 0755 ext/cli/prune %{buildroot}%{appdir}/cli/apps/prune
install -p -D -m 0755 ext/cli/ruby %{buildroot}%{appdir}/cli/apps/ruby

install -p -D -m 0644 %{SOURCE1} %{buildroot}%{_sysusersdir}/%{name}.conf
install -p -D -m 0644 ext/redhat/puppetserver.service %{buildroot}%{_unitdir}/%{service}.service
install -p -D -m 0644 ext/default %{buildroot}%{_sysconfdir}/sysconfig/%{service}

mkdir -p -m 0755 %{buildroot}%{etcdir}/ca
install -p -D -m 0644 ext/config/conf.d/auth.conf %{buildroot}%{etcdir}/conf.d/auth.conf
install -p -D -m 0644 ext/config/conf.d/ca.conf %{buildroot}%{etcdir}/conf.d/ca.conf
install -p -D -m 0644 ext/config/conf.d/global.conf %{buildroot}%{etcdir}/conf.d/global.conf
install -p -D -m 0644 ext/config/conf.d/metrics.conf %{buildroot}%{etcdir}/conf.d/metrics.conf
install -p -D -m 0644 ext/config/conf.d/puppetserver.conf %{buildroot}%{etcdir}/conf.d/puppetserver.conf
install -p -D -m 0644 ext/config/conf.d/web-routes.conf %{buildroot}%{etcdir}/conf.d/web-routes.conf
install -p -D -m 0644 ext/config/conf.d/webserver.conf %{buildroot}%{etcdir}/conf.d/webserver.conf

install -p -D -m 0644 ext/config/request-logging.xml %{buildroot}%{etcdir}/request-logging.xml
install -p -D -m 0644 ext/config/logback.xml %{buildroot}%{etcdir}/logback.xml

install -p -D -m 0644 ext/config/services.d/ca.cfg %{buildroot}%{etcdir}/services.d/ca.cfg

mkdir -p -m 0755 %{buildroot}%{serverdir}/data/puppetserver/{yaml,jars}

%pre
%if 0%{?rhel} >= 9 || 0%{?fedora} > 0
%sysusers_create_compat %{SOURCE1}
%elif 0%{?rhel} > 0
# TODO sysusers
%elif 0{?sles_version} > 0
# TODO sysusers
%service_add_pre %{service}.service
%endif

%post
%if 0%{?rhel} > 0 || 0%{?fedora} > 0
%systemd_post %{service}.service
%elif 0{?sles_version} > 0
%service_add_post %{service}.service
%endif

%postinstall
if [ "$1" = "1" ]; then
    : # Null command in case additional_postinst_install is empty
    #/opt/puppetlabs/puppet/bin/puppet config set --section master vardir  /opt/puppetlabs/server/data/puppetserver
    #/opt/puppetlabs/puppet/bin/puppet config set --section master logdir  /var/log/puppetlabs/puppetserver
    #/opt/puppetlabs/puppet/bin/puppet config set --section master rundir  /var/run/puppetlabs/puppetserver
    #/opt/puppetlabs/puppet/bin/puppet config set --section master pidfile /var/run/puppetlabs/puppetserver/puppetserver.pid
    #/opt/puppetlabs/puppet/bin/puppet config set --section master codedir /etc/puppetlabs/code
    #install --directory /etc/puppetlabs/puppet/ssl
    #chown -R puppet:puppet /etc/puppetlabs/puppet/ssl
    #find /etc/puppetlabs/puppet/ssl -type d -print0 | xargs -0 chmod 770
fi

%preun
%if 0%{?rhel} > 0 || 0%{?fedora} > 0
%systemd_preun %{service}.service
%elif 0{?sles_version} > 0
%service_del_preun %{service}.service
%endif

%postun
%if 0%{?rhel} > 0 || 0%{?fedora} > 0
%systemd_postun_with_restart %{service}.service
%elif 0{?sles_version} > 0
%service_del_postun %{service}.service
%endif

%files
# apps
/opt/puppetlabs/bin/puppetserver
%{appdir}/cli/apps

# service
%{appdir}/config/services.d/bootstrap.cfg
%{appdir}/puppet-server-release.jar

%dir %attr(0775,puppet,puppet) %{serverdir}/data
%dir %attr(0775,puppet,puppet) %{serverdir}/data/puppetserver
%dir %attr(0700,puppet,puppet) %{serverdir}/data/puppetserver/jars
%dir %attr(0750,puppet,puppet) %{serverdir}/data/puppetserver/yaml

# TODO: LICENSE
%doc %{_docdir}/%{name}/ezbake.manifest

# vendored gems
/opt/puppetlabs/puppet/lib/ruby/vendor_gems
%attr(0755,puppet,puppet) %{serverdir}/data/puppetserver/vendored-jruby-gems

# systemd
%{_sysusersdir}/%{name}.conf
%{_unitdir}/%{service}.service
%config(noreplace) %{_sysconfdir}/sysconfig/%{service}

# configs
# TODO: why owned by puppet?
%dir %attr(0750,puppet,puppet) %{etcdir}/ca
%config(noreplace) %{etcdir}/conf.d/auth.conf
%config(noreplace) %{etcdir}/conf.d/ca.conf
%config(noreplace) %{etcdir}/conf.d/global.conf
%config(noreplace) %{etcdir}/conf.d/metrics.conf
%config(noreplace) %{etcdir}/conf.d/puppetserver.conf
%config(noreplace) %{etcdir}/conf.d/web-routes.conf
%config(noreplace) %{etcdir}/conf.d/webserver.conf
%config(noreplace) %{etcdir}/logback.xml
%config(noreplace) %{etcdir}/request-logging.xml
%config(noreplace) %{etcdir}/services.d/ca.cfg

%changelog
%autochangelog
