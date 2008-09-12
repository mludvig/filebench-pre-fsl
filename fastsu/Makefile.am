#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

bin_PROGRAMS = fastsu
fastsu_SOURCES = fastsu.c

DEFS = -D_REENTRANT @DEFINES@

BUILD = @BUILD@

pkg: fastsu
	mkdir -p $(BUILD)
	cp fastsu $(BUILD)

