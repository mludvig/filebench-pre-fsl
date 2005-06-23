#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $nfiles=1000
set $dirwidth=20
set $filesize=16k
set $nthreads=1
set $meaniosize=16k

define fileset name=postset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$dirwidth,prealloc
define fileset name=postsetdel,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$dirwidth,prealloc

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop openfile name=openfile1,filesetname=postset,fd=1
    flowop appendfilerand name=appendfilerand1,iosize=$meaniosize,fd=1
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile2,filesetname=postset,fd=1
    flowop readwholefile name=readfile1,fd=1
    flowop closefile name=closefile2,fd=1
    flowop deletefile name=deletefile1,filesetname=postsetdel
  }
}

echo  "Mongo-like Version $Revision: 1.11 $ $Date: 2005/06/21 21:18:52 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>    defaults to $filesize"
usage "       set \$nfiles=<value>     defaults to $nfiles"
usage "       set \$dirwidth=<value>   defaults to $dirwidth"
usage "       set \$nthreads=<value>   defaults to $nthreads"
usage "       set \$meaniosize=<value> defaults to $meaniosize"
usage "       run runtime (e.g. run 60)"
