#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $filesize=5g
set $nthreads=1
set $iosize=1m

define file name=largefile1,path=$dir,size=$filesize,prealloc,reuse

define process name=seqread,instances=1
{
  thread name=seqread,memsize=10m,instances=$nthreads
  {
    flowop read name=seqread,filename=largefile1,iosize=$iosize,directio
    flowop bwlimit name=limit
  }
}

echo  "Single Stream Read Version $Revision: 1.3 $ $Date: 2005/06/09 23:25:59 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>    defaults to $filesize"
usage "       set \$nthreads=<value>   defaults to $nthreads"
usage "       set \$iosize=<value> defaults to $iosize"
usage " "
usage "This workload needs $filesize of disk space by default"
usage " "
usage "       run runtime (e.g. run 60)"
