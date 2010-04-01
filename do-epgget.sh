#!/bin/sh

CHTYPE=$1
CHANNEL=$2

TMPTS=$(tempfile).ts

RECPT1=/usr/local/bin/recpt1
DURATION=60

EPGDUMP=/usr/local/bin/epgdump

$RECPT1 --b25 --strip $CHANNEL $DURATION $TMPTS
$EPGDUMP $CHTYPE$CHANNEL $TMPTS -

rm -f $TMPTS
