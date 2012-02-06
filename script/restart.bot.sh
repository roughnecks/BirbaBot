#!/bin/bash

if [ ! -f "$1" ]; then 
    echo "Usage: $0 configurationfile.conf"
fi

botdir=$(dirname $0)



if [ ! -f "$botdir/birba.pid" ]; then
    cd $botdir
    exec perl birbabot.pl >> birba.log 2>&1
fi

pid=$(cat $botdir/birba.pid)
logfile=$botdir/birba.log

if kill -0 $pid > /dev/null 2>&1 ; then 
    exit
else
    cd $botdir
    echo -n $(date) >> birba.log
    echo "Bot restarted by $0" >> birba.log
    perl birbabot.pl $1 >> birba.log 2>&1 &
    exit 0
fi
