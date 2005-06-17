/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#ifndef FILESET_H
#define FILESET_H

#include <config.h>

#ifndef HAVE_OFF64_T
/* We are probably on linux
 * according to http://www.suse.de/~aj/linux_lfs.html, defining the
 * above, automatically changes type of off_t to off64_t. so let
 * us use only off_t as off64_t is not defined
 */
#define off64_t off_t
#endif /* HAVE_OFF64_T */


#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/resource.h>
#include <pthread.h>
#include <gsl/gsl_randist.h>

#include "fileobj.h"

#define FSE_MAXTID 16384

#define FSE_MAXPATHLEN 16
#define FSE_DIR        0x1
#define FSE_FREE       0x2
#define FSE_EXISTS     0x4
#define FSE_BUSY       0x8

typedef struct filesetentry {
	struct filesetentry *fse_next;
	struct filesetentry *fse_parent;
	struct filesetentry *fse_filenext;   /* List of files */
	struct filesetentry *fse_dirnext;    /* List of directories */
	struct fileset      *fse_fileset;    /* Parent fileset */
	pthread_mutex_t      fse_lock;
	char                *fse_path;
	int                  fse_depth;
	off64_t              fse_size;
	int                  fse_flags;
} filesetentry_t;

#define FILESET_PICKANY      0x1 /* Pick any file from the set */
#define FILESET_PICKUNIQUE   0x2 /* Pick a unique file from the set until empty */
#define FILESET_PICKRESET    0x4 /* Reset FILESET_PICKUNIQUE selection list */
#define FILESET_PICKDIR      0x8 /* Pick a directory */
#define FILESET_PICKEXISTS  0x10 /* Pick an existing file */
#define FILESET_PICKNOEXIST 0x20 /* Pick a file that doesn't exist */

typedef struct fileset {
	struct fileset *fs_next;            /* Next in list */
	char           fs_name[128];        /* Name */
	pthread_t      fs_tid;              /* Thread id, for par alloc */
	var_string_t   fs_path;             /* Pathname prefix in fs */
	var_integer_t  fs_entries;          /* Set size */
	var_integer_t  fs_preallocpercent;  /* Prealloc size */
	int            fs_attrs;            /* Attributes */
	var_integer_t  fs_dirwidth;         /* Explicit or 0 for distribution */
	var_integer_t  fs_size;             /* Explicit or 0 for distribution */
	var_integer_t  fs_dirgamma;         /* Dirwidth Gamma distribution (* 1000) */
	var_integer_t  fs_sizegamma;        /* Filesize Gamma distribution (* 1000) */
	var_integer_t  fs_create;           /* Attr */
	var_integer_t  fs_prealloc;         /* Attr */
	var_integer_t  fs_cached;           /* Attr */
	var_integer_t  fs_reuse;            /* Attr */
	double         fs_meandepth;        /* Computed mean depth */
	double         fs_meanwidth;        /* Specified mean dir width */
	double         fs_meansize;         /* Specified mean file size */
	gsl_rng        *fs_rand;            /* File set random number generator */
	const gsl_rng_type *fs_rantype;     /* File set random number type */
	int            fs_realfiles;        /* Actual files */
	off64_t        fs_bytes;            /* Space potentially consumed by all files */
	filesetentry_t *fs_filelist;        /* List of files */
	filesetentry_t *fs_dirlist;         /* List of directories */
	filesetentry_t *fs_filefree;        /* Ptr to next free file */
	filesetentry_t *fs_dirfree;         /* Ptr to next free directory */
	filesetentry_t *fs_filerotor[FSE_MAXTID]; /* Ptr to next file to select */
	filesetentry_t *fs_dirrotor;        /* Ptr to next directory to select */
} fileset_t;

int fileset_createset(fileset_t *);
int fileset_initset(fileset_t *);
int fileset_openfile(fileset_t *fileset, filesetentry_t *entry, 
	int flag, int mode, int attrs);
fileset_t *fileset_define(char *);
fileset_t *fileset_find(char *name);
filesetentry_t *fileset_pick(fileset_t *fileset, int flags, int tid);
char *fileset_resolvepath(filesetentry_t *entry);
void      fileset_usage();

#endif
