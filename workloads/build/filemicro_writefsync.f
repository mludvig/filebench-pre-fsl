#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

#  3- open() and allocation of a 1GB file with write()
#     of size picked uniformly in [1K,8K] range and issuing
#     fsync() every 10MB.

set $dir=/tmp
set $nthreads=1
set $iosize=8k
set $count=128k
set $iters=1250

define fileset name=bigfileset,path=$dir,size=0,entries=128,dirwidth=1024,prealloc=100

define process name=filecreater,instances=1
{
  thread name=filecreaterthread,memsize=10m,instances=$nthreads
  {
    flowop appendfile name=append-file,filesetname=bigfileset,iosize=$iosize,fd=1,iters=$iters
    flowop fsync name=sync-file,fd=1
    flowop finishoncount name=finish,value=$count
  }
}

echo  "FileMicro-WriteFsync Version 1.8 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$count=<value>    defaults to $count"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage " "
usage "       run runtime (e.g. run 60)"
