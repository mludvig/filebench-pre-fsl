#!/bin/sh
# Change the ulimit file descriptor number
ulimit -n 1024

workloads="fileserver bringover createfiles deletefiles varmail webproxy webserver"
filesystem=$1

for personality in $workloads
do
/opt/filebench/bin/filebench<<EOF
load $personality
debug 2
set \$dir=/filebench/fstest/1
set \$nfiles=100000
create filesets
create files
create processes
stats clear
sleep 60
stats snap
stats dump "stats.$personality.$filesystem"
shutdown processes
quit
EOF
done

workloads="randomread randomwrite singlestreamread singlestreamwrite multistreamread multistreamwrite singlestreamreaddirect singlestreamwritedirect multistreamreaddirect multistreamwritedirect"
for personality in $workloads
do
/opt/filebench/bin/filebench<<EOF
load $personality
debug 2
set \$dir=/filebench/fstest/1
set \$filesize=5g
create files
create processes
stats clear
sleep 30
stats snap
stats dump "stats.$personality.$filesystem"
shutdown processes
quit
EOF
done

workloads="oltp"
for personality in $workloads
do
/opt/filebench/bin/filebench<<EOF
load $personality
debug 2
set \$dir=/filebench/fstest/1
set \$filesize=5g
create files
create processes
stats clear
sleep 300
stats snap
stats dump "stats.$personality.$filesystem"
shutdown processes
quit
EOF
done

