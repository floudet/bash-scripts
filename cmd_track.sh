#!/bin/bash
# Command track script
# Description: Log all bash commands to syslog  
# Author: Fabien Loudet
# Tested on Ubuntu 10.04, 12.04 
# Installation instructions:
#   Copy this script in '/etc/profile.d/' and setup logging for local6 with a new file:
#   /etc/rsyslog.d/bash.conf
#   contents :
#   local6.*	/var/log/cmd_track.log 
#   restart rsyslog

declare -r REAL_LOGNAME=`/usr/bin/who -m | cut -d" " -f1`
declare -r LOGINFROM=`/usr/bin/who -m | sed 's/.*(\([^)]*\))/\1/'`

if [ $USER == root ]; then
    declare -r PROMT="#"
else
    declare -r PROMT="$"
fi

if [ -z $LOGINFROM ]; then
	LOGINFROM=$HOSTNAME
fi

LAST_HISTORY="$(history 1)"
__LAST_COMMAND="${LAST_HISTORY/*[0-9][0-9] /}"

log2syslog() { 

THIS_HISTORY="$(history 1)"
__THIS_COMMAND="${THIS_HISTORY/*[0-9][0-9] /}"

if [ "$LAST_HISTORY" != "$THIS_HISTORY" ]; then
    __LAST_COMMAND="$__THIS_COMMAND"
    LAST_HISTORY="$THIS_HISTORY"
    logger -p local6.debug -i "$REAL_LOGNAME $LOGINFROM [$USER@$HOSTNAME:$PWD]$PROMT$__LAST_COMMAND"
fi

}

trap log2syslog DEBUG
