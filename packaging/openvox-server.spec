%global serverdir /opt/puppetlabs/server
# TODO use name
%global etcdir %{_sysconfdir}/puppetlabs/puppetserver

Name:           openvox-server
Version:        8.9.0
Release:        1%{?dist}
Summary:        Server component for OpenVox agents
License:        Apache-2.0
URL:            https://voxpupuli.org
Source0:        https://artifacts.voxpupuli.org/%{name}/%{version}/%{name}-%{version}.tar.gz
Source1:        openvox-server.service
Source2:        openvox-server.sysusers

BuildArch: noarch

BuildRequires: systemd-rpm-macros
# For the ruby_vendorlibdir
BuildRequires: ruby-devel
%{?sysusers_requires_compat}

Requires: jre-17-headless
Requires: openvox-agent >= 8
# Requires: rubygem(puppetserver-ca)

%description
Server component

# inside the tarball there's still puppetserver
%prep
%setup -n puppetserver-%{version}

%install
install -p -D -m 0644 puppet-server-release.jar %{buildroot}%{_datadir}/%{name}/puppet-server-release.jar
install -p -D -m 0644 ext/system-config/services.d/bootstrap.cfg %{buildroot}%{_datadir}/%{name}/services.d/bootstrap.cfg

install -p -D -m 0644 ext/ezbake.manifest %{buildroot}%{_docdir}/%{name}/ezbake.manifest

# TODO: should rubygem-puppetserver-ca actually ship this file?
install -p -D -m 0755 ext/cli/ca %{buildroot}%{serverdir}/apps/ca
# official packages also ship: foreground, irb, gem, reload, ruby, start, stop

install -p -D -m 0644 %{SOURCE2} %{buildroot}%{_sysusersdir}/%{name}.conf
install -p -D -m 0644 %{SOURCE1} %{buildroot}%{_unitdir}/%{name}.service

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

mkdir -p -m 0755 %{buildroot}%{_sharedstatedir}/%{name}

%pre
%sysusers_create_compat %{SOURCE2}

%post
%systemd_post %{name}.service

%preun
%systemd_preun %{name}.service

%postun
%systemd_postun_with_restart %{name}.service

%files
%{_datadir}/%{name}/puppet-server-release.jar
%{_datadir}/%{name}/services.d/bootstrap.cfg

# TODO: LICENSE
%{_docdir}/%{name}/ezbake.manifest

%{_bindir}/%{name}
#%{_libexecdir}/%{name}/apps/ca

%{_sysusersdir}/%{name}.conf
%{_unitdir}/%{name}.service

%dir %attr(0750,puppet,puppet) %{_sharedstatedir}/%{name}

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
