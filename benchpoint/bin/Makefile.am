#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

bin_SCRIPTS = runbench

runbench: benchpoint Makefile.in
	sed 's:DEFINE_FILEBENCHDIR:@FILEBENCHDIR@:g' benchpoint | \
	sed 's:DEFINE_PROGDIR:@FILEBENCHBIN@:g' >runbench
