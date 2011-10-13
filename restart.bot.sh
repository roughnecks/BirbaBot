#!/bin/bash


botdir=$(dirname $0)

if [ ! -f "$botdir/birba.pid" ]; then
    exec perl $botdir/birbabot.pl >> birba.log 2>&1
fi

pid=$(cat $botdir/birba.pid)
logfile=$botdir/birba.log


if kill -0 $pid; then 
    exit
else
    echo -n $(date) >> birba.log
    echo "Bot restarted by $0" >> birba.log
    exec perl $botdir/birbabot.pl >> birba.log 2>&1
fi
