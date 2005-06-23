#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

# 7- Sequential write() of a 1G file, size picked uniformly in
#    the [1K,8K] range, followed by close(), cached.



set $dir=/tmp
set $nthreads=1
set $iosize=8k
set $cached=0
set $sync=0
set $count=128k

define fileset name=bigfileset,path=$dir,size=0,entries=$nthreads,dirwidth=1024,prealloc=100,cached=$cached

define process name=filewriter,instances=1
{
  thread name=filewriterthread,memsize=10m,instances=$nthreads
  {
    flowop appendfilerand name=write-file,dsync=$sync,filesetname=bigfileset,iosize=$iosize,fd=1,iters=$count
    flowop closefile name=close,fd=1
    flowop finishoncount name=finish,value=1
  }
}

echo  "FileMicro-SeqWriteRand Version $Revision: 1.7 $ $Date: 2005/06/21 21:18:52 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage "       set \$cached=<bool>    defaults to $cached"
usage "       set \$count=<bool>     defaults to $cached"
usage "       set \$sync=<bool>      defaults to $cached"
usage " "
usage "       run runtime (e.g. run 60)"
