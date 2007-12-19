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

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$dirwidth,prealloc=100
define fileset name=destfiles,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$dirwidth

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop openfile name=openfile1,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile1,fd=1
    flowop createfile name=createfile2,filesetname=destfiles,fd=2
    flowop writewholefile name=writefile2,filesetname=destfiles,fd=2,srcfd=1
    flowop closefile name=closefile1,fd=1
    flowop closefile name=closefile2,fd=2
  }
}

echo  "CopyFiles Version 1.6 2005/06/21 21:18:52 personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>   defaults to $filesize"
usage "       set \$nfiles=<value>    defaults to $nfiles"
usage "       set \$dirwidth=<value>  defaults to $dirwidth"
usage "       set \$nthreads=<value>  defaults to $nthreads"
usage "       run runtime (e.g. run 60)"
