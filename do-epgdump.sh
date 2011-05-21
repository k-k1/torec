#!/bin/sh

if [ -z $1 ]; then
  echo "usage: $0 [CHTYPE(GR/BS)] [CHANNEL] [DURATION(default 60sec)]"
  exit
fi

CHTYPE=$1
CHANNEL=$2
if [ -z $3 ]; then
  DURATION=60
else
  DURATION=$3
fi

TMPTS=$(tempfile --suffix=.ts)

RECPT1=/usr/local/bin/recpt1
EPGDUMP=/usr/local/bin/epgdump

$RECPT1 --b25 --strip $CHANNEL $DURATION $TMPTS 2>/dev/null
if [ $CHTYPE = 'BS' ]; then
  CHANNEL='/BS'
  $EPGDUMP /$CHTYPE $TMPTS -
else
  $EPGDUMP $CHTYPE$CHANNEL $TMPTS -
fi

rm -f $TMPTS
