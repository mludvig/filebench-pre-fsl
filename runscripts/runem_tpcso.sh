#!/bin/ksh

# Run with directio on all filesystems
mount -o remount,forcedirectio /export/home/tpcso/filebench
mount -o remount,forcedirectio /export/home/tpcso/logs
/opt/filebench/bin/benchpoint tpcso

# Run with directio on logs only
mount -o remount,noforcedirectio /export/home/tpcso/filebench
mount -o remount,forcedirectio /export/home/tpcso/logs
/opt/filebench/bin/benchpoint tpcso

# Run with no directio on filesystems
mount -o remount,noforcedirectio /export/home/tpcso/filebench
mount -o remount,noforcedirectio /export/home/tpcso/logs
/opt/filebench/bin/benchpoint tpcso
