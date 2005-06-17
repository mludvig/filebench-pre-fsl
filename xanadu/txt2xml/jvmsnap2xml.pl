#!/bin/csh

set dir=`dirname $0`

java -cp $dir/../bin JVMSnap2Xml $1 $2
