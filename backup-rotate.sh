#!/bin/bash
#
# backup-rotate.sh: Simple script to rotate backups
# Rotate directories named after the sheme d01..d0x where x is RETENTION 
# e.g. a number of days. Create directories if they don't exist
# The script takes 1 argument which is the backup base directory name
# 
# Author: Fabien Loudet

if [ $# -lt 1 ];then
        echo "No args, you should provide a directory name"
        exit -1
fi

BACKUPDIR="/var/backups/$1"
LOG="/var/log/backup-rotate.log"
RETENTION=15 #in days, min 2 days, max 99 days
BACKUPUSR="backup" #ownership of newly created directories 

function log {
	echo $(date +"%b %e %T") $HOSTNAME $1 | tee -a $LOG
} 

if [ ! -d $BACKUPDIR ];then
	log "unable to find backup directory '$BACKUPDIR'"
	exit -1
fi	

if [ $RETENTION -lt 2 ];then 
	log "Retention should be at least 2 days, sorry."
	exit -1
fi


if [ $RETENTION -ge 99 ];then 
	log "Retention is limited to 99 days, sorry."
	exit -1
fi

#Create initial directories if not exist
for i in $(seq -w 01 $RETENTION); do
	if [ ! -d $BACKUPDIR/d$i ]; then
		install -d -m 0755 -o $BACKUPUSR -g $BACKUPUSR $BACKUPDIR/d$i
		if [ $? -ne 0 ];then
			log "failed to create '$BACKUPDIR/d$i'"
		else
			log "'$BACKUPDIR/d$i' successfully created"
		fi
	fi  
done

#Remove extra directories if RETENTION is decreased
for i in $(seq -w 99 -1 $(($RETENTION+1))); do
	if [ -d $BACKUPDIR/d$i ];then
		log "Retention has been decreased to $RETENTION days, attempting to remove extra directory '$BACKUPDIR/d$i'"
		rm -Rf $BACKUPDIR/d$i
		if [ $? -ne 0 ];then
			log "Error while removing '$BACKUPDIR/d$i'"
		else
			log "'$BACKUPDIR/d$i' was successfully removed"
		fi
	fi 
done

#We shift all directories 
log "Starting to shift directories"
SHIFTERRORS=0
rm -Rf $BACKUPDIR/d$(printf "%02d" $RETENTION)
if [ $? -ne 0 ];then ((SHIFTERRORS++)); fi
for i in $(seq -f "%02g" $RETENTION -1 2); do
	mv $BACKUPDIR/d$(printf "%02d" $(( ${i#0} -1 ))) $BACKUPDIR/d$i
	if [ $? -ne 0 ];then ((SHIFTERRORS++)); fi
done
install -d -m 0755 -o $BACKUPUSR -g $BACKUPUSR $BACKUPDIR/d01
if [ $? -ne 0 ];then ((SHIFTERRORS++)); fi
if [ $SHIFTERRORS -ne 0 ];then
	log "Error while trying to shift the directories"
else
	log "Directories successfully shifted, ready for next full backup!"
fi
