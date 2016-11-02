#!/bin/sh

# Setup key at node:
# cat .ssh/id_rsa.pub | ssh root@node 'cat >> .ssh/authorized_keys ; chmod 600 .ssh/authorized_keys; chmod 700 .ssh'

# Crontab exmples:
# daily backups 
#10 1 * * * /backup/rdiff/daily/rdiff-backup-daily.sh
# monthly backups
#30 3 1 * * /backup/rdiff/monthly/rdiff-backup-monthly.sh


# Settings
BACKUPDIR=/backup/rdiff/daily

# Define rdiff-backup params
RDIFFCMD="rdiff-backup --ssh-no-compression --preserve-numerical-ids --exclude-device-files --exclude-fifos --exclude-sockets "

#Remove  the  incremental  backup  information  in the destination directory that has been around longer than the 7 days
REMOVEOLDDEF=7D

PIDFILE="/var/run/`basename $0`.pid"
LOGFILE="/var/log/`basename $0`.log"
# Maximum log size in MB
MAXLOGSIZE=100


export LC_ALL=C
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/root/bin


checkerr()
{
if [ $1 -ne 0 ];
then
echo "`date` Error: $@" >> ${LOGFILE}
echo "`date` Error: $@"
fi
}

log()
{
echo "==> `date` $@" >> ${LOGFILE}
}

checkpid()
{
if [ -f "${PIDFILE}" ]; then
pgrep -P  `cat ${PIDFILE}`
	if [ $? -eq 0 ]; then
	echo $0 already running with pid=`cat ${PIDFILE}`
	exit
	else
	echo $$ > ${PIDFILE}
	fi
else
	echo $$ > ${PIDFILE}
fi
}

rotatelog()
{
if [ -f ${LOGFILE} ]; then
	LOGSIZE=`du -m ${LOGFILE} | awk '{print $1}'`
	if [ ${LOGSIZE} -gt ${MAXLOGSIZE} ]; then 
	 log "Rotate log"
	 mv ${LOGFILE} ${LOGFILE}.1
	if [ -f ${LOGFILE}.1.bz2 ]; then
	 mv ${LOGFILE}.1.bz2 ${LOGFILE}.2.bz2
	fi
	bzip2 ${LOGFILE}.1
	fi
fi
}

deletebackups()
{
log "== Delete OLD backups for host=$IP: rdiff-backup --force --remove-older-than ${REMOVEOLD} $1"
rdiff-backup --force --remove-older-than ${REMOVEOLD} $1 >> ${LOGFILE}
ERR=$?
checkerr $ERR rdiff-backup --remove-older-than ${REMOVEOLD} $1
}


backup ()
{
TARGETDIR=$1
# read conf for host
IP=""
REMOVEOLD=""
PRECMD=""
POSTCMD=""
. ./$TARGETDIR/conf 


if [ -z "${REMOVEOLD}" ]; then 
	REMOVEOLD=${REMOVEOLDDEF}
fi

# run command befor backup
if [ -n "${PRECMD}" ]; then
log "== Run PRECMD: $PRECMD"
       ${PRECMD} >> ${LOGFILE}
ERR=$?
checkerr $ERR $PRECMD
fi

# BACKUP:
log "== Begin backup for host=$IP: $RDIFFCMD --include-globbing-filelist $TARGETDIR/include $IP::/ $TARGETDIR/ROOT"
$RDIFFCMD --include-globbing-filelist $TARGETDIR/include $IP::/ $TARGETDIR/ROOT >> ${LOGFILE}
ERR=$?
checkerr $ERR $RDIFFCMD --include-globbing-filelist $TARGETDIR/include $IP::/ $TARGETDIR/ROOT

if [ $ERR -eq 0 ]; then
deletebackups $TARGETDIR/ROOT
fi

# run command after backup
if [ -n "${POSTCMD}" ]; then
log "== Run POSTCMD: $POSTCMD"
       ${POSTCMD} >> ${LOGFILE}
ERR=$?
checkerr $ERR $POSTCMD
fi

}


####################################################################################################################################
# main

checkpid
rotatelog
log "=============================================================================================================================="
log "========= Start with pid $$"

cd $BACKUPDIR

if [ $# -eq 0 ]
then
    # backup dirs in $BACKUPDIR
    for target in $(ls -d */)
    do
	backup `basename ${target}`
    done
else
    # backup command line 
    while [ "$1" ]
    do
        backup $1
        shift
    done
fi


