#!/bin/bash

if [ ! -f "$1" ]; then
    echo "Usage: $0 configurationfile.conf"
fi

botdir=$(dirname $0)

if [ ! -d "$botdir/logs" ]; then
	mkdir "$botdir/logs"
fi

logfile=$botdir/logs/birba-`date +%F`.log

if [ ! -f "$botdir/birba.pid" ]; then
    cd $botdir
    exec perl birbabot.pl >> "$logfile" 2>&1
fi

pid=$(cat $botdir/birba.pid)

if kill -0 $pid > /dev/null 2>&1 ; then
    exit
else
    cd $botdir
    echo -n $(date) >> "$logfile"
    echo "Bot restarted by $0" >> "$logfile"
    perl birbabot.pl $1 >> "$logfile" 2>&1 &
    exit 0
fi
