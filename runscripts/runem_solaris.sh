#!/bin/sh
# Change the ulimit file descriptor number
ulimit -n 1024

# Operating System variable
os="Solaris_8"

# Run filebench workloads
for profile in randomread
do
	# Set the operating_system variable to appear in the results
	cat /opt/filebench/profiles/${profile}.prof | sed "/operating_system = .*/ s//operating_system = $os;/" > /opt/filebench/profiles/${profile}.prof2
	mv /opt/filebench/profiles/${profile}.prof2 /opt/filebench/profiles/${profile}.prof
	/opt/filebench/bin/benchpoint $profile
done
