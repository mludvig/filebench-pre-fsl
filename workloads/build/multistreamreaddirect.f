#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $nthreads=1
set $iosize=1m

define file name=largefile1,path=$dir
define file name=largefile2,path=$dir
define file name=largefile3,path=$dir
define file name=largefile4,path=$dir

define process name=seqread,instances=1
{
  thread name=seqread1,memsize=10m,instances=$nthreads
  {
    flowop read name=seqread1,filename=largefile1,iosize=$iosize,directio
    flowop bwlimit name=limit
  }
  thread name=seqread2,memsize=10m,instances=$nthreads
  {
    flowop read name=seqread2,filename=largefile2,iosize=$iosize,directio
    flowop bwlimit name=limit
  }
  thread name=seqread3,memsize=10m,instances=$nthreads
  {
    flowop read name=seqread3,filename=largefile3,iosize=$iosize,directio
    flowop bwlimit name=limit
  }
  thread name=seqread4,memsize=10m,instances=$nthreads
  {
    flowop read name=seqread4,filename=largefile4,iosize=$iosize,directio
    flowop bwlimit name=limit
  }
}

echo  "Multi Stream Read Direct Version 1.6 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>    defaults to $filesize"
usage "       set \$nthreads=<value>   defaults to $nthreads"
usage "       set \$iosize=<value> defaults to $iosize"
usage " "
usage "       run runtime (e.g. run 60)"

