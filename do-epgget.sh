#!/bin/sh

CHTYPE=$1
CHANNEL=$2
DURATION=${3:=60}

TMPTS=$(tempfile --suffix=.ts)

RECPT1=/usr/local/bin/recpt1

EPGDUMP=/usr/local/bin/epgdump

$RECPT1 --b25 --strip $CHANNEL $DURATION $TMPTS 2>/dev/null
if [ $CHTYPE = 'BS' ]; then
  CHTYPE='/BS'
  CHANNEL=''
fi
$EPGDUMP $CHTYPE$CHANNEL $TMPTS -

rm -f $TMPTS
