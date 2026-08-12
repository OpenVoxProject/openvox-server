#!/bin/bash

set -ex

################
# Usage: controller.sh <os> <version> <basepath>
# The controller script does all of the jar compilation
# and setup needed to build packages for <os>
# The os string should be one of el, redhatfips, sles, debian, ubuntu,
# or fedora
# The version should be the numerical OS version for el,
# redhatfips, sles, and fedora and the codename for debian/ubuntu.
# The resulting artifacts will be stored in <basepath>
################
build_os=$1
build_ver=$2
basepath=$3

if [ ! -d "$basepath" ]; then
  mkdir -p $basepath
fi
if [ ! -d "$basepath/base" ]; then
        DESTDIR="$basepath/base" bash install.sh install_redhat
fi
if [ ! -d "$basepath/systemd_el" ]; then
        cp -r "$basepath/base" "$basepath/systemd_el"
        DESTDIR="$basepath/systemd_el" bash install.sh systemd_redhat
fi
if [ ! -d "$basepath/old_el" ]; then
        cp -r "$basepath/base" "$basepath/old_el"
        DESTDIR="$basepath/old_el" bash install.sh sysv_init_redhat
fi
if [ ! -d "$basepath/old_sles" ]; then
        cp -r "$basepath/base" "$basepath/old_sles"
        DESTDIR="$basepath/old_sles" bash install.sh sysv_init_suse
fi


# things are only different if we have docs, deb docs get
# installed in an unversioned folder but rpm docs get installed
# in a versioned folder.
if [ -d ext/docs ]; then
        if [ ! -d "$basepath/base_deb" ]; then
                DESTDIR="$basepath/base_deb" bash install.sh install_deb
                if [ ! -d "$basepath/systemd_deb" ]; then
                        cp -r "$basepath/base_deb" "$basepath/systemd_deb"
                        DESTDIR="$basepath/systemd_deb" bash install.sh systemd_deb
                fi
                if [ ! -d "$basepath/systemd_notasksmax_deb" ]; then
                        cp -r "$basepath/base_deb" "$basepath/systemd_notasksmax_deb"
                        DESTDIR="$basepath/systemd_notasksmax_deb" USE_TASKSMAX=false bash install.sh systemd_deb
                fi
                if [ ! -d "$basepath/sysvinit_deb" ]; then
                        cp -r "$basepath/base_deb" "$basepath/sysvinit_deb"
                        DESTDIR="$basepath/sysvinit_deb" bash install.sh sysv_init_deb
                fi
        fi
else
        if [ ! -d "$basepath/systemd_deb" ]; then
                cp -r "$basepath/base" "$basepath/systemd_deb"
                DESTDIR="$basepath/systemd_deb" bash install.sh systemd_deb
        fi
        if [ ! -d "$basepath/systemd_notasksmax_deb" ]; then
                cp -r "$basepath/base" "$basepath/systemd_notasksmax_deb"
                DESTDIR="$basepath/systemd_notasksmax_deb" USE_TASKSMAX=false bash install.sh systemd_deb
        fi
        if [ ! -d "$basepath/sysvinit_deb" ]; then
                cp -r "$basepath/base" "$basepath/sysvinit_deb"
                DESTDIR="$basepath/sysvinit_deb" bash install.sh sysv_init_deb
        fi
fi

os=$build_os
if [ "$os" = "debian" ]; then
        os_dist=$build_ver
else
        os_version=$build_ver
fi

case $os in
        # there's no differences in packaging for deb vs ubuntu
        # if that changes we'll need to fix this
        debian|ubuntu)
                if [ "$os_dist" = 'trusty' ]; then
                        dir="$basepath/sysvinit_deb"
                elif [ "$os_dist" = 'jessie' ]; then
                        # the version of systemd that ships with jessie doesn't
                        # support TasksMax
                        dir="$basepath/systemd_notasksmax_deb"
                else
                        dir="$basepath/systemd_deb"
                fi
                ;;
        el|redhatfips)
                if [ "$os_version" -gt '6' ]; then
                        dir="$basepath/systemd_el"
                else
                        dir="$basepath/old_el"
                fi
                ;;
        amazon)
                dir="$basepath/systemd_el"
                ;;
        sles)
                if [ "$os_version" -gt '11' ]; then
                        dir="$basepath/systemd_el"
                else
                        dir="$basepath/old_sles"
                fi
                ;;
        *)
                echo "I have no idea what I'm doing with $os, teach me?" >&2
                exit 1
                ;;
esac

# bash will eat your spaces, so let's array. see http://mywiki.wooledge.org/BashFAQ/050 for more fun.
params=("--user" "puppet" "--group" "puppet" "--chdir" "$dir" "--realname" "puppetserver" "--operating-system" "$os" "--name" "openvox-server" "--package-version" "8.11.0" "--release" "1" "--platform-version" "8")
if [ -n "$os_version" ]; then params+=("--os-version" "$os_version"); fi
if [ -n "$os_dist" ]; then params+=("--dist" "$os_dist"); fi

params+=('--description' "$(printf "Vox Pupuli puppetserver\nContains: OpenVox Server (puppetlabs/puppetserver 8.11.0,org.clojure/clojure 1.11.2,org.bouncycastle/bcpkix-jdk18on 1.78.1,puppetlabs/jruby-utils 5.2.0,puppetlabs/puppetserver 8.11.0,com.puppetlabs/trapperkeeper-webserver-jetty10 1.0.18,puppetlabs/trapperkeeper-metrics 2.0.4)")")



params+=('--replaces' "'puppetserver',''")


params+=('--create-dir' '/opt/puppetlabs/server/data/puppetserver/jars')
params+=('--create-dir' '/opt/puppetlabs/server/data/puppetserver/yaml')



if [[ "$os" = 'el' || "$os" = 'sles' || "$os" = 'fedora' || "$os" = 'redhatfips' || "$os" = 'amazon' ]]; then
        # pull in rpm dependencies
                        params+=("--additional-dependency")
                params+=("openvox-agent >= 8.21.1")
                # get rpm install trigger scripts
                # get rpm upgrade trigger scripts
                : # Need something in case there are no additional dependencies
else
        # if we aren't an rpm, pull in deb dependencies
                        params+=("--additional-dependency")
                params+=("openvox-agent (>= 8.21.1)")
                                        : # Need something in case there are no additional dependencies
fi


ruby $PWD/ext/fpm.rb "${params[@]}"
