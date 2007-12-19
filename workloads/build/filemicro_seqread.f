#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

# 4- Sequential read(32K) of a 1G file, cached 
# 5- Sequential read(32K) of a 1G file, uncached 

set $dir=/tmp
set $nthreads=1
set $iosize=1m
set $filesize=1g
set $cached=0

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nthreads,dirwidth=1024,prealloc=100,cached=$cached

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop read name=append-file,filesetname=bigfileset,iosize=$iosize,fd=1
  }
}

echo  "FileMicro-SeqRead Version 1.8 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$filesize=<size>  defaults to $filesize"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage "       set \$cached=<bool>    defaults to $cached"
usage " "
usage "       run runtime (e.g. run 60)"
