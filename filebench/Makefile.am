#
# Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License.
# See the file LICENSING in this distribution for details.
#

bin_PROGRAMS = go_filebench
filebench_SOURCES = gamma_dist.c misc.c procflow.c threadflow.c \
                    utils.c flowop.c flowop_library.c ipc.c \
		    vars.c stats.c eventgen.c fileset.c fb_random.c \
		    parser_gram.y parser_lex.l
filebenchdir = $(datadir)/filebench
INCLUDES = -I../intl -DFILEBENCHDIR=\"$(prefix)/filebench\"

MV=@MV@
LEX=@LEX@
YACC=@YACC@
LFLAGS = @LFLAGS@
YFLAGS = @YFLAGS@
DEFS = -D_REENTRANT @DEFINES@
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

