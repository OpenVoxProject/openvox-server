%global serverdir /opt/puppetlabs/server
# TODO use datadir variable?
%global appdir %{serverdir}/apps/puppetserver
# TODO use name variable?
%global etcdir %{_sysconfdir}/puppetlabs/puppetserver
%global service puppetserver

Name:           openvox-server
Version:        8.9.0
Release:        1%{?dist}
Summary:        Server component for OpenVox agents
License:        Apache-2.0
URL:            https://voxpupuli.org
Source0:        https://artifacts.voxpupuli.org/%{name}/%{version}/%{name}-%{version}.tar.gz
Source1:        openvox-server.sysusers

BuildArch: noarch

BuildRequires: systemd-rpm-macros
%{?sysusers_requires_compat}

%if 0%{?rhel} >= 10 || 0%{?fedora}
%global java jre-21-headless
%global java_bin /usr/lib/jvm/jre-21/bin/java
%elif 0%{?rhel} >= 8
%global java jre-17-headless
%global java_bin /usr/lib/jvm/jre-17/bin/java
%elif 0%{?rhel}
%global java jre-11-headless
%global java_bin /usr/lib/jvm/jre-11/bin/java
%elif 0%{?suse_version}
%global java java-11-openjdk-headless
%elif 0%{?amzn}
# TODO: also a build requirement?
Requires: tzdata-java
%global java (java-17-amazon-corretto-headless or java-11-amazon-corretto-headless)
%else
# TODO: probably wrong
%global java java-1.8.0-openjdk-headless
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
# TODO: this needs internet access
DESTDIR=%{buildroot} bash ext/build-scripts/install-vendored-gems.sh

%if 0%{?rhel} || 0%{?fedora}
sed -i 's|/usr/bin/java|%{java_bin}|' ext/redhat/puppetserver.service
%endif

%install
install -p -D -m 0644 puppet-server-release.jar %{buildroot}%{appdir}/puppet-server-release.jar
install -p -D -m 0644 ext/system-config/services.d/bootstrap.cfg %{buildroot}%{appdir}/config/services.d/bootstrap.cfg

install -p -D -m 0644 ext/ezbake.manifest %{buildroot}%{_docdir}/%{name}/ezbake.manifest

# TODO: should rubygem-puppetserver-ca actually ship this file?
install -p -D -m 0755 ext/cli/ca %{buildroot}%{appdir}/cli/apps/ca
install -p -D -m 0755 ext/cli/irb %{buildroot}%{appdir}/cli/apps/irb
install -p -D -m 0755 ext/cli/gem %{buildroot}%{appdir}/cli/apps/gem
install -p -D -m 0755 ext/cli/prune %{buildroot}%{appdir}/cli/apps/prune
install -p -D -m 0755 ext/cli/ruby %{buildroot}%{appdir}/cli/apps/ruby

install -p -D -m 0644 %{SOURCE1} %{buildroot}%{_sysusersdir}/%{name}.conf
install -p -D -m 0644 ext/redhat/puppetserver.service %{buildroot}%{_unitdir}/%{service}.service

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
%{appdir}/cli/apps
%{appdir}/config/services.d/bootstrap.cfg
%{appdir}/puppet-server-release.jar
%dir %attr(0700,puppet,puppet) %{serverdir}/data/puppetserver/jars
%dir %attr(0700,puppet,puppet) %{serverdir}/data/puppetserver/yaml

# TODO: LICENSE
%doc %{_docdir}/%{name}/ezbake.manifest

# TODO: why don't the gems install?
#/opt/puppetlabs/puppet/lib/ruby/vendor_gems
#/opt/puppetlabs/server/data/puppetserver/vendored-jruby-gems

%{_sysusersdir}/%{name}.conf
%{_unitdir}/%{service}.service
# TODO: sysconfig

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
