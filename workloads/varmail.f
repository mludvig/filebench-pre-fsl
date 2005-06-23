#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

set $dir=/tmp
set $nfiles=1000
set $meandirwidth=1000000
set $filesize=16k
set $nthreads=16
set $meaniosize=16k

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=80

define process name=filereader,instances=1
{
  thread name=filereaderthread,memsize=10m,instances=$nthreads
  {
    flowop deletefile name=deletefile1,filesetname=bigfileset
    flowop createfile name=createfile2,filesetname=bigfileset,fd=1
    flowop appendfilerand name=appendfilerand2,iosize=$meaniosize,fd=1
    flowop fsync name=fsyncfile2,fd=1
    flowop closefile name=closefile2,fd=1
    flowop openfile name=openfile3,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile3,fd=1
    flowop appendfilerand name=appendfilerand3,iosize=$meaniosize,fd=1
    flowop fsync name=fsyncfile3,fd=1
    flowop closefile name=closefile3,fd=1
    flowop openfile name=openfile4,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile4,fd=1
    flowop closefile name=closefile4,fd=1
  }
}

echo  "Varmail Version $Revision: 1.24 $ $Date: 2005/06/22 08:08:30 $ personality successfully loaded"
usage "Usage: set \$dir=<dir>"
usage "       set \$filesize=<size>    defaults to $filesize"
usage "       set \$nfiles=<value>     defaults to $nfiles"
usage "       set \$nthreads=<value>   defaults to $nthreads"
usage "       set \$meaniosize=<value> defaults to $meaniosize"
usage "       set \$meandirwidth=<size> defaults to $meandirwidth"
usage "(sets mean dir width and dir depth is calculated as log (width, nfiles)"
usage " dirdepth therefore defaults to dir depth of 1 as in postmark"
usage " set $meandir lower to increase depth beyond 1 if desired)"
usage " "
usage "       run runtime (e.g. run 60)"

