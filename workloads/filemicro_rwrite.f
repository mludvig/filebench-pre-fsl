#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

# 10- 128M worth of 2K write(2) (to random offset), open with
#     O_DSYNC, uncached.

set $dir=/tmp
set $nthreads=1
set $iosize=2k
set $bytes=128m
set $iters=1
set $cached=0
set $filesize=1g

define file name=bigfile1,path=$dir,size=$filesize,prealloc,reuse,cached=$cached

define process name=filewriter,instances=1
{
  thread name=filewriterthread,memsize=10m,instances=$nthreads
  {
    flowop write name=write-file,filename=bigfile1,random,dsync,iosize=$iosize,iters=$iters
    flowop finishonbytes name=finish,value=$bytes
  }
}

echo  "FileMicro-WriteRandDsync Version $Revision: 1.5 $ $Date: 2005/06/21 21:18:52 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>  defaults to $filesize"
usage "       set \$iosize=<size>    defaults to $iosize"
usage "       set \$bytes=<value>    defaults to $bytes"
usage "       set \$cached=<value>   defaults to $cached"
usage "       set \$nthreads=<value> defaults to $nthreads"
usage " "
usage "       run runtime (e.g. run 60)"
