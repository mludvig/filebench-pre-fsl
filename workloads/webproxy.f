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
set $nthreads=100
set $meaniosize=16k

define fileset name=bigfileset,path=$dir,size=$filesize,entries=$nfiles,dirwidth=$meandirwidth,prealloc=80

define process name=proxycache,instances=1
{
  thread name=proxycache,memsize=10m,instances=$nthreads
  {
    flowop deletefile name=deletefile1,filesetname=bigfileset
    flowop createfile name=createfile1,filesetname=bigfileset,fd=1
    flowop appendfilerand name=appendfilerand1,iosize=$meaniosize,fd=1
    flowop closefile name=closefile1,fd=1
    flowop openfile name=openfile2,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile2,fd=1
    flowop closefile name=closefile2,fd=1
    flowop openfile name=openfile3,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile3,fd=1
    flowop closefile name=closefile3,fd=1
    flowop openfile name=openfile4,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile4,fd=1
    flowop closefile name=closefile4,fd=1
    flowop openfile name=openfile5,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile5,fd=1
    flowop closefile name=closefile5,fd=1
    flowop openfile name=openfile6,filesetname=bigfileset,fd=1
    flowop readwholefile name=readfile6,fd=1
    flowop closefile name=closefile6,fd=1
    flowop opslimit name=limit
  }
}

echo  "Proxy Cache Version $Revision: 1.13 $ $Date: 2005/06/21 21:18:53 $ personality successfully loaded"
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
