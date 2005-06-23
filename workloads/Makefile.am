#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

filebenchdir = $(datadir)/filebench

SUBDIRS = build

pkg: filebench
	@mkdir -p build
	@for f in *.f ; do cat $$f |sed 's/$$Revision: //' | \
	sed 's/$$ $$Date: //'| \
	sed 's/$$ //' >build/$$f; \
	echo "Processing workload $$f"; \
	done;

