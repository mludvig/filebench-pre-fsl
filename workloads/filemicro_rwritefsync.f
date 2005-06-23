#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

# 128M worth of random 8K-aligned write(2) to a 1G file; followed by fsync(); cached.

set $dir=/tmp
set $nthreads=1
set $iosize=8k
set $count=1
set $iters=16384
set $filesize=1g
set $cached=0

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nthreads,dirwidth=1024,prealloc=100,cached=$cached

define process name=filewriter,instances=1
{
  thread name=filewriterthread,memsize=10m,instances=$nthreads
  {
    flowop writefile name=write-file,filesetname=bigfileset,random,iosize=$iosize,fd=1,iters=$iters
    flowop fsync name=sync-file,fd=1
    flowop finishoncount name=finish,value=$count
  }
}

echo  "FileMicro-WriteRandFsync Version $Revision: 1.7 $ $Date: 2005/06/21 21:18:52 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$count=<value>    defaults to $count"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage "       set \$cached=<value>   defaults to $cached"
usage " "
usage "       run runtime (e.g. run 60)"
