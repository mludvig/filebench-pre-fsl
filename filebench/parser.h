/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>
#include "vars.h"

#ifndef sun
typedef unsigned char uchar_t;
#endif

#define E_ERROR 1
#define E_USAGE 2
#define FS_FALSE 0
#define FS_TRUE 1

#define FSE_SYSTEM 1

typedef struct list {
	struct list   *list_next;
        var_string_t  list_string;
        var_integer_t list_integer;
} list_t;

typedef struct attr {
	int           attr_name;
	struct attr  *attr_next;
        var_string_t  attr_string;
        var_integer_t attr_integer;
        list_t        *attr_param_list;
} attr_t;

typedef struct cmd {
	void (*cmd)(struct cmd *);
	char       *cmd_name;
	char       *cmd_tgt1;
	char       *cmd_tgt2;
	char       *cmd_tgt3;
	char       *cmd_tgt4;
	char       *thread_name;
	uint64_t   cmd_qty;
	struct cmd *cmd_list;
	struct cmd *cmd_next;
	attr_t     *cmd_attr_list;
        list_t     *cmd_param_list;
        list_t     *cmd_param_list2;
} cmd_t;

typedef union {
	int64_t i;
	uchar_t b;
        char *s;
} fs_u;

typedef struct pidlist {
        struct pidlist *pl_next;
	int            pl_fd;
        pid_t          pl_pid;
} pidlist_t;

typedef void (*cmdfunc)(cmd_t *);

