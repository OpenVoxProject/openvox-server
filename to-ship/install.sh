#!/usr/bin/env bash

set -e

if [ -n "${EZ_VERBOSE}" ]; then
    set -x
fi

USE_TASKSMAX=${USE_TASKSMAX:-true}

# Warning: This variable API is experimental so these variables may be subject
# to change in the future.
prefix=${prefix:=/usr}
initdir=${initdir:=/etc/init.d}
unitdir_redhat=${unitdir:-/usr/lib/systemd/system}
unitdir_debian=${unitdir:-/lib/systemd/system}
defaultsdir_redhat=${defaultsdir:-/etc/sysconfig}
defaultsdir_debian=${defaultsdir:-/etc/default}
tmpfilesdir=${tmpfilesdir:=/usr/lib/tmpfiles.d}
datadir=${datadir:=${prefix}/share}
real_name=${real_name:=puppetserver}
projdatadir=${projdatadir:=${datadir}/${real_name}}
confdir=${confdir:=/etc}
projconfdir=${projconfdir:=${confdir}/puppetlabs/${real_name}}
rundir=${rundir:=/var/run/puppetlabs/${real_name}}
# Application specific bin directory
bindir=${bindir:=/opt/puppetlabs/server/apps/${real_name}/bin}
# User facing bin directory, expected to be added to interactive shell PATH
uxbindir=${uxbindir:=/opt/puppetlabs/bin}
# symlinks of server binaries
symbindir=${symbindir:=/opt/puppetlabs/server/bin}
app_prefix=${app_prefix:=/opt/puppetlabs/server/apps/${real_name}}
dest_apps_dir="${DESTDIR}${app_prefix}"
app_data=${app_data:=/opt/puppetlabs/server/data/${real_name}}
app_logdir=${app_logdir:=/var/log/puppetlabs/${real_name}}
system_config_dir=${system_config_dir:=${app_prefix}/config}
needrestart_confdir=${needrestart_dir:=/etc/needrestart/conf.d}


##################
# EZBake Vars    #
##################

if [ -n "${EZ_VERBOSE}" ]; then
    set +x
    echo "#-------------------------------------------------#"
    echo "The following variables are set: "
    echo
    env | sort

    echo
    echo "End of variable print."
    echo "#-------------------------------------------------#"
    set -x
fi

##################
# Task functions #
##################

# The below functions are exposed to the user to be able to be called from
# the command line directly.

# Catch all, to install the lot, with osdetection included etc.
function task_all {
    task service
    task termini
}

# Run installer, and automatically choose correct tasks using os detection.
function task_service {
    osdetection

    if [ "$OSFAMILY" = "RedHat" ]; then
        unitdir=${unitdir_redhat}
        defaultsdir=${defaultsdir_redhat}
        if [ $MAJREV -lt 7 ]; then
            task install_source_rpm_sysv
        else
            task install_source_rpm_systemd
        fi
    elif [ "$OSFAMILY" = "Debian" ]; then
        unitdir=${unitdir_debian}
        defaultsdir=${defaultsdir_debian}
        sysv_codenames=("squeeze" "wheezy" "lucid" "precise" "trusty")
        if $(echo ${sysv_codenames[@]} | grep -q $CODENAME) ; then
            task install_source_deb_sysv
        else
            task install_source_deb_systemd
        fi
    else
        echo "Unsupported platform, exiting ..."
        exit 1
    fi
}

# Source based install for Redhat based + sysv setups
function task_install_source_rpm_sysv {
    task preinst_redhat
    task install_redhat
    task sysv_init_redhat
    task logrotate_legacy
    task postinst_redhat
    task postinst_permissions
}

# Source based install for Redhat based + systemd setups
function task_install_source_rpm_systemd {
    task preinst_redhat
    task install_redhat
    task systemd_redhat
    task logrotate
    task postinst_redhat
    task postinst_permissions
}

# Source based install for Debian based + sysv setups
function task_install_source_deb_sysv {
    task preinst_deb
    task install_deb
    task sysv_init_deb
    task logrotate
    task postinst_deb
}

# Source based install for Debian based + systemd setups
function task_install_source_deb_systemd {
    task preinst_deb
    task install_deb
    task systemd_deb
    task logrotate
    task postinst_deb
}

# install docs for debian based systems
function task_install_docs_deb {
  if [ -d ext/docs ]; then
    install -d "${DESTDIR}${app_prefix}/share/doc/puppetserver"
    cp -a ext/docs "${DESTDIR}${app_prefix}/share/doc/puppetserver"
  fi
}

# install docs for rpm based systems
function task_install_docs_rpm {
  if [ -d ext/docs ]; then
    install -d "${DESTDIR}${app_prefix}/share/doc/puppetserver-8.11.0"
    cp -a ext/docs "${DESTDIR}${app_prefix}/share/doc/puppetserver-8.11.0"
  fi
}

# Install the ezbake package software. This step is used during RPM &
# Debian packaging during the 'install' phases.
function task_install {
    install -d -m 0755 "${dest_apps_dir}"
    install -d -m 0770 "${DESTDIR}${app_data}"
    install -m 0644 puppet-server-release.jar "${dest_apps_dir}"
    install -m 0755 ext/ezbake-functions.sh "${dest_apps_dir}"
    install -m 0644 ext/ezbake.manifest "${dest_apps_dir}"
    install -d -m 0755 "${DESTDIR}${projconfdir}/conf.d"

  
    install -d -m 0755 "${DESTDIR}${system_config_dir}/services.d"
    install -d -m 0755 "${DESTDIR}${projconfdir}/services.d"

        install -m 0644 ext/system-config/services.d/bootstrap.cfg "${DESTDIR}${system_config_dir}/services.d/bootstrap.cfg"
    
    install -m 0644 ext/config/conf.d/puppetserver.conf "${DESTDIR}${projconfdir}/conf.d/puppetserver.conf"
    install -m 0644 ext/config/request-logging.xml "${DESTDIR}${projconfdir}/request-logging.xml"
    install -m 0644 ext/config/logback.xml "${DESTDIR}${projconfdir}/logback.xml"
    install -m 0644 ext/config/conf.d/global.conf "${DESTDIR}${projconfdir}/conf.d/global.conf"
    install -m 0644 ext/config/conf.d/web-routes.conf "${DESTDIR}${projconfdir}/conf.d/web-routes.conf"
    install -m 0644 ext/config/conf.d/auth.conf "${DESTDIR}${projconfdir}/conf.d/auth.conf"
    install -m 0644 ext/config/conf.d/metrics.conf "${DESTDIR}${projconfdir}/conf.d/metrics.conf"
    install -m 0644 ext/config/conf.d/ca.conf "${DESTDIR}${projconfdir}/conf.d/ca.conf"
    install -m 0644 ext/config/conf.d/webserver.conf "${DESTDIR}${projconfdir}/conf.d/webserver.conf"
    install -m 0644 ext/config/services.d/ca.cfg "${DESTDIR}${projconfdir}/services.d/ca.cfg"

    install -d -m 0755 "${dest_apps_dir}/scripts"
    install -m 0755 install.sh "${dest_apps_dir}/scripts"

    install -d -m 0755 "${dest_apps_dir}/cli"
    install -d -m 0755 "${dest_apps_dir}/cli/apps"
    install -d -m 0755 "${DESTDIR}${bindir}"
    install -m 0755 "ext/bin/${real_name}" "${DESTDIR}${bindir}/${real_name}"
    install -d -m 0755 "${DESTDIR}${symbindir}"
    ln -s "../apps/${real_name}/bin/${real_name}" "${DESTDIR}${symbindir}/${real_name}"
    install -d -m 0755 "${DESTDIR}${uxbindir}"
    ln -s "../server/apps/${real_name}/bin/${real_name}" "${DESTDIR}${uxbindir}/${real_name}"
    install -m 0755 ext/cli/foreground "${dest_apps_dir}/cli/apps/foreground"
    install -m 0755 ext/cli/irb "${dest_apps_dir}/cli/apps/irb"
    install -m 0755 ext/cli/ca "${dest_apps_dir}/cli/apps/ca"
    install -m 0755 ext/cli/gem "${dest_apps_dir}/cli/apps/gem"
    install -m 0755 ext/cli/stop "${dest_apps_dir}/cli/apps/stop"
    install -m 0755 ext/cli/start "${dest_apps_dir}/cli/apps/start"
    install -m 0755 ext/cli/ruby "${dest_apps_dir}/cli/apps/ruby"
    install -m 0755 ext/cli/reload "${dest_apps_dir}/cli/apps/reload"
    install -m 0755 ext/cli/prune "${dest_apps_dir}/cli/apps/prune"

if [ -e "ext/cli_defaults/cli-defaults.sh" ]; then
    install -m 0755 ext/cli_defaults/cli-defaults.sh "${dest_apps_dir}/cli/"
fi

    install -d -m 0755 "${DESTDIR}${rundir}"
    install -d -m 700 "${DESTDIR}${app_logdir}"
    install -d -m 700 "${DESTDIR}/opt/puppetlabs/server/data/puppetserver/jars"
    install -d -m 700 "${DESTDIR}/opt/puppetlabs/server/data/puppetserver/yaml"
}

function task_install_redhat {
    task install
    task install_docs_rpm
    bash ./ext/build-scripts/install-vendored-gems.sh
}

function task_install_deb {
    task install
    task install_docs_deb
    bash ./ext/build-scripts/install-vendored-gems.sh
}


function task_defaults_redhat {
    install -d -m 0755 "${DESTDIR}${defaultsdir_redhat}"
    install -m 0644 ext/default "${DESTDIR}${defaultsdir_redhat}/puppetserver"
}

function task_defaults_deb {
    install -d -m 0755 "${DESTDIR}${defaultsdir_debian}"
    install -m 0644 ext/debian/puppetserver.default_file "${DESTDIR}${defaultsdir_debian}/puppetserver"
}

# Install the sysv and defaults configuration for Redhat.
function task_sysv_init_redhat {
    task defaults_redhat
    install -d -m 0755 "${DESTDIR}${initdir}"
    install -m 0755 ext/redhat/init "${DESTDIR}${initdir}/puppetserver"
}

# Install the sysv and defaults configuration for SuSE.
function task_sysv_init_suse {
    task defaults_redhat
    install -d -m 0755 "${DESTDIR}${initdir}"
    install -m 0755 ext/redhat/init.suse "${DESTDIR}${initdir}/puppetserver"
}

# Install the systemd and defaults configuration for Redhat.
function task_systemd_redhat {
    task defaults_redhat
    install -d -m 0755 "${DESTDIR}${unitdir_redhat}"
    install -m 0644 ext/redhat/puppetserver.service "${DESTDIR}${unitdir_redhat}/puppetserver.service"
    install -d -m 0755 "${DESTDIR}${tmpfilesdir}"
    install -m 0644 ext/puppetserver.tmpfiles.conf "${DESTDIR}${tmpfilesdir}/puppetserver.conf"
}

# Install the sysv and defaults configuration for Debian.
function task_sysv_init_deb {
    task defaults_deb
    install -d -m 0755 "${DESTDIR}${initdir}"
    install -m 0755 ext/debian/puppetserver.init_script "${DESTDIR}${initdir}/puppetserver"
    install -d -m 0755 "${DESTDIR}${rundir}"
}

# Install the systemd/sysv and defaults configuration for Debian.
function task_systemd_deb {
    task sysv_init_deb
    install -d -m 0755 "${DESTDIR}${unitdir_debian}"
    install -m 0644 ext/debian/puppetserver.service_file "${DESTDIR}${unitdir_debian}/puppetserver.service"
    if [ "$USE_TASKSMAX" == "false" ]; then
      sed -i "s/^TasksMax/# Don't set TasksMax since the option doesn't exist\n# TasksMax/" "${DESTDIR}${unitdir_debian}/puppetserver.service"
    fi
    install -d -m 0755 "${DESTDIR}${tmpfilesdir}"
    install -m 0644 ext/puppetserver.tmpfiles.conf "${DESTDIR}${tmpfilesdir}/puppetserver.conf"
    install -d -m 0755 "${DESTDIR}${needrestart_confdir}"
    install -m 0644 ext/puppetserver.needrestart.conf "${DESTDIR}${needrestart_confdir}/puppetserver.conf"
}

function task_service_account {
    # Add puppet group
    getent group puppet > /dev/null || \
        groupadd -r puppet || :
    # Add or update puppet user
    if getent passwd puppet > /dev/null; then
        usermod --gid puppet --home "${app_data}" \
            --comment "puppetserver daemon" puppet || :
    else
        useradd -r --gid puppet --home "${app_data}" --shell $(which nologin) \
            --comment "puppetserver daemon"  puppet || :
    fi
}

# RPM based pre-installation tasks.
# Note: Any changes to this section may require synchronisation with the
# packaging, due to the fact that we can't access this script from the pre
# section of an rpm/deb.
function task_preinst_redhat {
    task service_account
}

# Debian based pre-installation tasks.
# Note: Any changes to this section may require synchronisation with the
# packaging, due to the fact that we can't access this script from the pre
# section of an rpm/deb.
function task_preinst_deb {
    task service_account
}

# Debian based unconditional post-installation tasks.
function task_postinst_deb {
    task postinst_permissions
}

# Debian based install post-installation tasks.
function task_postinst_deb_install {
    : # Null command in case additional_postinst_install is empty
    install --owner=puppet --group=puppet -d /opt/puppetlabs/server/data/puppetserver/jruby-gems
    /opt/puppetlabs/puppet/bin/puppet config set --section master vardir  /opt/puppetlabs/server/data/puppetserver
    /opt/puppetlabs/puppet/bin/puppet config set --section master logdir  /var/log/puppetlabs/puppetserver
    /opt/puppetlabs/puppet/bin/puppet config set --section master rundir  /var/run/puppetlabs/puppetserver
    /opt/puppetlabs/puppet/bin/puppet config set --section master pidfile /var/run/puppetlabs/puppetserver/puppetserver.pid
    /opt/puppetlabs/puppet/bin/puppet config set --section master codedir /etc/puppetlabs/code
    usermod --home /opt/puppetlabs/server/data/puppetserver puppet
    install --directory --owner=puppet --group=puppet --mode=775 /opt/puppetlabs/server/data
    install --directory /etc/puppetlabs/puppet/ssl
    chown -R puppet:puppet /etc/puppetlabs/puppet/ssl
    find /etc/puppetlabs/puppet/ssl -type d -print0 | xargs -0 chmod 770
}

# RPM based unconditional post-installation tasks.
function task_postinst_redhat {
    : # Null command in case additional_postinst is empty
}

# RPM based install post-installation tasks.
function task_postinst_redhat_install {
    : # Null command in case additional_postinst_install is empty
    install --owner=puppet --group=puppet -d /opt/puppetlabs/server/data/puppetserver/jruby-gems
    /opt/puppetlabs/puppet/bin/puppet config set --section master vardir  /opt/puppetlabs/server/data/puppetserver
    /opt/puppetlabs/puppet/bin/puppet config set --section master logdir  /var/log/puppetlabs/puppetserver
    /opt/puppetlabs/puppet/bin/puppet config set --section master rundir  /var/run/puppetlabs/puppetserver
    /opt/puppetlabs/puppet/bin/puppet config set --section master pidfile /var/run/puppetlabs/puppetserver/puppetserver.pid
    /opt/puppetlabs/puppet/bin/puppet config set --section master codedir /etc/puppetlabs/code
    usermod --home /opt/puppetlabs/server/data/puppetserver puppet
    install --directory --owner=puppet --group=puppet --mode=775 /opt/puppetlabs/server/data
    install --directory /etc/puppetlabs/puppet/ssl
    chown -R puppet:puppet /etc/puppetlabs/puppet/ssl
    find /etc/puppetlabs/puppet/ssl -type d -print0 | xargs -0 chmod 770
}

# Global post installation permissions setup. Not to be used by Redhat
# during package based installation, as this is done by the RPM itself
# by the %files definitions
function task_postinst_permissions {
    chown puppet:puppet /var/log/puppetlabs/puppetserver
    chmod 700 /var/log/puppetlabs/puppetserver
    chown puppet:puppet $app_data
    chmod 770 $app_data
    chown puppet:puppet $projconfdir
    chmod 750 $projconfdir
    chown puppet:puppet $rundir
    chmod 0755 $rundir
    chown puppet:puppet /opt/puppetlabs/server/data/puppetserver/jars
    chmod 700 /opt/puppetlabs/server/data/puppetserver/jars
    chown puppet:puppet /opt/puppetlabs/server/data/puppetserver/yaml
    chmod 700 /opt/puppetlabs/server/data/puppetserver/yaml
}

# Install logrotate (usually el7, fedora 16 and above)
function task_logrotate {
    install -d -m 0755 "${DESTDIR}${confdir}/logrotate.d"
    cp -pr ext/puppetserver.logrotate.conf "${DESTDIR}${confdir}/logrotate.d/puppetserver"
}

# Install legacy logrotate
function task_logrotate_legacy {
    install -d -m 0755 "${DESTDIR}${confdir}/logrotate.d"
    cp -pr ext/puppetserver.logrotate-legacy.conf "${DESTDIR}${confdir}/logrotate.d/puppetserver"
}

##################
# Misc functions #
##################

# Print output only if EZ_VERBOSE is set
function debug_echo {
    if [ -n "${EZ_VERBOSE}" ]; then
        echo $@
    fi
}

# Do basic OS detection using facter.
function osdetection {
    OSFAMILY=`facter osfamily`
    MAJREV=`facter operatingsystemmajrelease`
    CODENAME=`facter os.distro.codename`

    debug_echo "OS Detection results"
    debug_echo
    debug_echo "OSFAMILY: ${OSFAMILY}"
    debug_echo "MAJREV: ${MAJREV}"
    debug_echo "CODENAME: ${CODENAME}"
    debug_echo
}

# Run a task
# Accepts:
#   $1 = task to run
function task {
    local task=$1
    shift
    debug_echo "Running task ${task} ..."
    eval task_$task $@
}

# List available tasks
#
# Gathers a list of all functions starting with task_ so it can be displayed
# or used by other functions.
function available_tasks {
    declare -F | awk '{ print $3 }' | grep '^task_*' | cut -c 6-
}

# Dispatch a task from the CLI
# Accepts:
#   $1 = task to dispatch
function dispatch {
    local task=$1
    shift
    if [ -z "$task" ]; then
        echo "Starting full installation ..."
        echo
        task all
    elif [ "$1" = "-h" ]; then
        echo "Usage: $0 <task>"
        echo
        echo "Choose from one of the following tasks:"
        echo
        echo "$(available_tasks)"
        echo
        echo "Warning: this task system is still experimental and may be subject to change without notice"
        return 1
    else
        task $task $@
    fi
}

########
# Main #
########
dispatch $@
