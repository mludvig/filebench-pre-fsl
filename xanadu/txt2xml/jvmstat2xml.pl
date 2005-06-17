#!/bin/csh

set dir=`dirname $0`

java -cp $dir/../WEB-INF/classes org.xanadu.txt.JVMStat2Xml $1 $2 $dir/jvmstat.props 5
