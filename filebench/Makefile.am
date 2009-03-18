#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

bin_PROGRAMS = go_filebench
go_filebench_SOURCES = auto_comp.c eventgen.c fb_avl.c fb_localfs.c \
		    fb_random.c fileset.c flowop.c flowop_library.c \
		    gamma_dist.c ipc.c misc.c multi_client_sync.c \
		    parser_gram.y parser_lex.l procflow.c stats.c \
		    threadflow.c utils.c vars.c
INCLUDES = -I../intl -DFILEBENCHDIR=\"$(datadir)/filebench\"

MV=@MV@
LEX=@LEX@
YACC=@YACC@
AM_LFLAGS = @LFLAGS@
AM_YFLAGS = @YFLAGS@
DEFS = -D_REENTRANT @DEFINES@
LIBS = @LDLIBS@
BUILD = @BUILD@

parser_lex.c: parser_lex.l parser_gram.h Makefile
	$(LEX) $(LFLAGS) parser_lex.l > $@

parser_gram.h parser_gram.c: parser_gram.y Makefile
	$(YACC) $(YFLAGS) parser_gram.y
	@mv y.tab.h parser_gram.h
	@mv y.tab.c parser_gram.c

pkg: go_filebench
	mkdir -p $(BUILD)
	cp go_filebench $(BUILD)

