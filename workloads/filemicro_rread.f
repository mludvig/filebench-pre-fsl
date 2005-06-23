#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $nthreads=1
set $iosize=2k
set $bytes=128m
set $iters=1
set $filesize=1g

define file name=bigfile1,path=$dir,size=$filesize,prealloc,reuse,cached=$cached

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop read name=write-file,filesetname=bigfile1,random,iosize=$iosize,iters=$iters
    flowop finishonbytes name=finish,value=$bytes
  }
}

echo  "FileMicro-ReadRand Version $Revision: 1.7 $ $Date: 2005/06/21 21:18:52 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>  defaults to $filesize"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$bytes=<value>    defaults to $bytes"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage " "
usage "       run runtime (e.g. run 60)"
