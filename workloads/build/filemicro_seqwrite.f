#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

# 4- Sequential write(32K) of a 1G file, cached 
# 5- Sequential write(32K) of a 1G file, uncached 

set $dir=/tmp
set $nthreads=1
set $iosize=1m
set $cached=0

define fileset name=bigfileset,path=$dir,size=0,entries=$nthreads,dirwidth=1024,prealloc=100,cached=$cached

define process name=filewriter,instances=1
{
  thread name=filewriterthread,memsize=10m,instances=$nthreads
  {
    flowop appendfile name=write-file,dsync=$sync,filesetname=bigfileset,iosize=$iosize,fd=1,iters=$count
    flowop closefile name=close,fd=1
    flowop finishoncount name=finish,value=1
  }
}

echo  "FileMicro-SeqWrite Version 1.7 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage "       set \$cached=<bool>    defaults to $cached"
usage " "
usage "       run runtime (e.g. run 60)"
