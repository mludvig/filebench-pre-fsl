#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $nthreads=1
set $iosize=8k
set $filesize=1m
set $workingset=0

define file name=largefile1,path=$dir,size=$filesize,prealloc,reuse,paralloc

define process name=rand-write,instances=1
{
  thread name=rand-thread,memsize=5m,instances=$nthreads
  {
    flowop write name=rand-write1,filename=largefile1,iosize=$iosize,random,workingset=$workingset
    flowop eventlimit name=rand-rate
  }
}


echo "Random Write Version $Revision: 1.4 $ $Date: 2005/06/21 21:18:52 $ IO personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>   defaults to $filesize"
usage "       set \$iosize=<value>    defaults to $iosize"
usage "       set \$nthreads=<value>  defaults to $nthreads"
usage "       set \$workingset=<value>  defaults to $workingset"
usage "       run runtime (e.g. run 60)"
