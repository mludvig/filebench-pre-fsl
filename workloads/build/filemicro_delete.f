#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

# delete 1000 files

set $dir=/tmp
set $nfiles=50000
set $meandirwidth=100
set $filesize=16k
set $nthreads=16
set $count=1000

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=100

define process name=filedelete,instances=1
{
  thread name=filedeletethread,memsize=10m,instances=$nthreads
  {
    flowop deletefile name=deletefile1,filesetname=bigfileset,fd=1
    flowop opslimit name=limit
    flowop finishoncount name=finish,value=$count
  }
}

echo  "FileMicro-Delete Version 1.7 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>     defaults to $filesize"
usage "       set \$nfiles=<value>      defaults to $nfiles"
usage "       set \$nthreads=<value>    defaults to $nthreads"
usage "       set \$count=<value>       defaults to $count"
usage "       set \$meandirwidth=<size> defaults to $meandirwidth"
usage "(sets mean dir width and dir depth is calculated as log (width, nfiles)"
usage " "
usage "       run runtime (e.g. run 60)"
