#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

filebenchdir = $(prefix)/filebench
workloadsdir = $(filebenchdir)/workloads

workloads_DATA = BUILD \
	bringover.f \
	copyfiles.f \
	createfiles.f \
	deletefiles.f \
	filemicro_create.f \
	filemicro_createfiles.f \
	filemicro_createrand.f \
	filemicro_delete.f \
	filemicro_rread.f \
	filemicro_rwrite.f \
	filemicro_rwritedsync.f \
	filemicro_rwritefsync.f \
	filemicro_seqread.f \
	filemicro_seqwrite.f \
	filemicro_seqwriterand.f \
	filemicro_writefsync.f \
	fileserver.f \
	mongo.f \
	multistreamread.f \
	multistreamreaddirect.f \
	multistreamwrite.f \
	multistreamwritedirect.f \
	oltp.f \
	postmark.f \
	randomread.f \
	randomwrite.f \
	singlestreamread.f \
	singlestreamreaddirect.f \
	singlestreamwrite.f \
	singlestreamwritedirect.f \
	tpcso.f \
	varmail.f \
	webproxy.f \
	webserver.f 

BUILD:
	@for f in ../*.f ; do cat $$f |sed 's/$$Revision: //' | \
	sed 's/$$ $$Date: //'| \
	sed 's/$$ //' >`basename $$f`; \
	done;

