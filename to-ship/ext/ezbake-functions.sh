#! /bin/bash
#
# Useful shell functions for programs packaged with ezbake.
#

#
# Wait `timeout` seconds for the application identified by `pid to bind to any
# TCP port
#
wait_for_app()
{
    local pid=${1:?}
    local timeout=${2:-300}

    while : ;do

        # verify the process is still running; if not, return failure
        ps -p $pid 2>&1 > /dev/null
        if [ "$?" != 0 ]; then
            return 1
        fi

        # if there are any TCP ports associated with the process, return success
        netstat -tulpn 2>/dev/null | grep "$pid" 2>&1 >/dev/null
        if [ "$?" = 0 ]; then
            sleep 5
            return 0
        fi

        # if we reach the timeout, return failure
        if [ "$timeout" = 0 ]; then
            return 1
        fi

        sleep 1
        timeout=$(($timeout-1))
    done
}


#
# Wait `timeout` seconds for `pidfile` to be created, otherwise return failure.
# Default timeout is 5 seconds.
#
wait_for_pidfile()
{
    local pidfile=${1:?}
    local timeout=${2:-5}

    while [ ! -s "$pidfile" ] ;do
        sleep 1

        # if we reach the timeout, return failure
        if [ "$timeout" -eq 0 ] ;then
            return 1
        fi

        timeout=$(($timeout-1))
    done

    return 0
}

#
# Kill a process.
#
# First argument (required) is the pid to kill.
#
# Second argument (optional) is a pidfile that should be removed after the
# process is killed.
#
# Third argument (optional) is a timeout (in seconds) to wait for the process
# to die.  Default timeout is 60 seconds.
#
# Returns 0 (success) if the process is dead or 1 (failure) if the process is
# still running after attempts to kill have completed.
#
kill_pid()
{
    local pid=${1:?}
    local pidfile=$2
    local stop_timeout=${3:-60}

    kill -TERM $pid >/dev/null 2>&1
    sleep 0.1

    timeout=$stop_timeout
    kill -0 $pid >/dev/null 2>&1
    while [ $? -eq 0 ] && [ $timeout -ne 0 ]; do
        sleep 1
        ((timeout--))
        kill -0 $pid >/dev/null 2>&1
    done

    if [ $timeout -eq 0 ]; then
        echo "Process $pid not terminated gracefully after $stop_timeout seconds" 1>&2
        kill -KILL $pid >/dev/null 2>&1
        sleep 1
        kill -0 $pid >/dev/null 2>&1
        timeout=$stop_timeout
        while [ $? -eq 0 ] && [ $timeout -ne 0 ]; do
            sleep 1
            ((timeout--))
            kill -0 $pid >/dev/null 2>&1
        done
        if [ $? -eq 0 ]; then
            echo "Process $pid not killed after SIGKILL" 1>&2
            return 1
        else
            echo "Process $pid killed after SIGKILL" 1>&2
        fi
    fi

    if [ -n "$pidfile" ]; then
        rm -f "$pidfile"
    fi

    return 0
}

init_restart_file()
{
    local restart_file="${1:?}"
    local restart_file_base_dir="$(dirname "$restartfile")"
    local user="${USER:-puppet}"
    local group="${GROUP:-puppet}"

    if [ ! -e "$restartfile" ]; then
        /usr/bin/install --directory --owner=$user --group=$group --mode=755 "$restart_file_base_dir"
        if [ $? -ne 0 ]; then
            echo "Unable to create or set permissions for restart file at ${restart_file_base_dir}" 1>&2
            return 1
        fi
        echo -n "0" > "$restart_file"
        if [ $? -ne 0 ]; then
            echo "Unable to create restart file at ${restart_file}" 1>&2
            return 1
        fi
        chown $user:$group "$restart_file"
        if [ $? -ne 0 ]; then
            echo "Unable to set permissions for restart file at ${restart_file}" 1>&2
            return 1
        fi
    elif [ ! -r "$restart_file" ] || [ ! -w "$restart_file" ]; then
        echo "The restart-file at ${restart_file} is not readable and/or writeable." 1>&2
        return 1
    fi

    return 0
}

if [ "$0" = "$BASH_SOURCE" ] ;then
    COMMAND=${1:?}
    export $(systemctl show -p MainPID puppetserver.service)
    case $COMMAND in
        wait_for_app)
            wait_for_app ${MainPID:?} ${START_TIMEOUT:-300}
        ;;
        *)
        ;;
    esac
fi
