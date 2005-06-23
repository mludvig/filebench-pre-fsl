#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

SUBDIRS 	= filebench fastsu workloads scripts benchpoint

TAR	   	= filebench.tar
TMPDIR          = /tmp/root.$$
SRCDIR          = @SRCDIR@

package: $(SUBDIRS)
	cd filebench; $(MAKE) pkg
	cd fastsu; $(MAKE) pkg
	cd solaris; $(MAKE)

$(TAR): FRC
	umask 000
	rm -rf $(TMPDIR)/filebench
	mkdir -p $(TMPDIR)/filebench
	find Makefile.in config/config* config/inst* scripts/filebench_* scripts/collect* configure config.h.in filebench/*.[chly] filebench/Makefile.in -print |\
	    cpio -pvd $(TMPDIR)/filebench
	cd $(TMPDIR); tar cvf $(SRCDIR)/filebench.tar filebench



