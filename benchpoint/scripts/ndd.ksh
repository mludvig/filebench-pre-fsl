#!/bin/ksh


PARAMS=`ndd /dev/tcp \? | grep -v "write only" | grep -v "\?" | grep -v "no read" | nawk '{ print $1 }'`


for p in $PARAMS
do
	rv=`ndd -get /dev/tcp $p`
	print "$p:\n$rv\n"
done

