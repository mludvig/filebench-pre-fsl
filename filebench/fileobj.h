/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#ifndef FILEOBJ_H
#define FILEOBJ_H

#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/resource.h>
#include <pthread.h>

#include "vars.h"

typedef struct fileobj {       
	char           fo_name[128];        /* Name */
	struct fileobj *fo_next;            /* Next in list */
	pthread_t      fo_tid;              /* Thread id, for par alloc */
	var_string_t   fo_path;             /* Pathname in fs */
	var_integer_t  fo_size;             /* Initial size */
	var_integer_t  fo_create;           /* Attr */
	var_integer_t  fo_prealloc;         /* Attr */
	var_integer_t  fo_paralloc;         /* Attr */
	var_integer_t  fo_reuse;            /* Attr */
	var_integer_t  fo_cached;           /* Attr */
	int            fo_attrs;            /* Attributes */
} fileobj_t;

#define FILE_ALLOC_BLOCK (off64_t)1024 * 1024

fileobj_t *fileobj_define(char *);
fileobj_t *fileobj_find(char *);
int       fileobj_init();
int       fileobj_open(fileobj_t *fileobj, int attrs);
void      fileobj_iter(int (*cmd)(fileobj_t *, int));
int       fileobj_print(fileobj_t *fileobj, int first);
void      fileobj_usage();

#endif
