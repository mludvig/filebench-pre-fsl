#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $nfiles=20000
set $meandirwidth=100000
set $filesize=1k
set $nthreads=1
set $count=5000

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=50

define process name=filecreate,instances=1
{
  thread name=filecreatethread,memsize=10m,instances=$nthreads
  {
    flowop createfile name=createfile1,filesetname=bigfileset,fd=1
    flowop writewholefile name=writefile1,filesetname=bigfileset,fd=1
    flowop closefile name=closefile1,fd=1
    flowop finishoncount name=finish,value=$count
  }
}

echo  "Createfiles Version 1.7 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>    defaults to $filesize"
usage "       set \$nfiles=<value>     defaults to $nfiles"
usage "       set \$count=<value>      defaults to $count"
usage "       set \$nthreads=<value>   defaults to $nthreads"
usage " "
usage "       run runtime (e.g. run 60)"
