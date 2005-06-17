#!/bin/sh
# Change the ulimit file descriptor number
ulimit -n 1024

#for fs in ufs zfs
for fs in ufs 
do

# Run all the filebench workloads
for file in filesets streamread oltp
do
	cat /opt/filebench/profiles/${file}.prof | sed "/filesystem = .*/ s//filesystem = $fs;/" > /opt/filebench/profiles/${file}.prof2
	mv /opt/filebench/profiles/${file}.prof2 /opt/filebench/profiles/${file}.prof
	/opt/filebench/bin/benchpoint $file
done

done
