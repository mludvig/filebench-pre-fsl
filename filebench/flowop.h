/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/resource.h>
#include <pthread.h>
#include "stats.h"
#include "threadflow.h"
#include "vars.h"
#include "fileset.h"
#include "filebench.h"

#ifndef FLOWSOP_H
#define FLOWSOP_H

typedef struct flowop {
	char           fo_name[128];          /* Name */
	int            fo_instance;           /* Instance number */
	struct flowop  *fo_next;              /* Next in global list */
	struct flowop  *fo_threadnext;        /* Next in thread's list */
	struct flowop  *fo_resultnext;        /* List of flowops in result */
	struct threadflow *fo_thread;         /* Backpointer to thread */
	int            (*fo_func)();          /* Method */
	int            (*fo_init)();          /* Init Method */
	int            (*fo_destruct)();      /* Destructor Method */
	int            fo_type;               /* Type */
	int            fo_attrs;              /* Flow op attribute */
	fileobj_t      *fo_file;              /* File for op */
	fileset_t      *fo_fileset;           /* Fileset for op */
	int            fo_fd;                 /* File descriptor */
	int            fo_fdnumber;           /* User specified file descriptor */
	int            fo_srcfdnumber;        /* User specified src file descriptor */
	var_integer_t  fo_iosize;             /* Size of operation */
	var_integer_t  fo_wss;                /* Flow op working set size */
	char           fo_targetname[128];    /* Target, for wakeup etc... */
	struct flowop  *fo_targets;           /* List of targets matching name */
	struct flowop  *fo_targetnext;        /* List of targets matching name */
	var_integer_t  fo_iters;              /* Number of iterations of op */
	var_integer_t  fo_value;              /* Attr */
	var_integer_t  fo_sequential;         /* Attr */
	var_integer_t  fo_random;             /* Attr */
	var_integer_t  fo_stride;             /* Attr */
	var_integer_t  fo_backwards;          /* Attr */
	var_integer_t  fo_dsync;              /* Attr */
	var_integer_t  fo_blocking;           /* Attr */
	var_integer_t  fo_directio;           /* Attr */
	var_integer_t  fo_rotatefd;           /* Attr */
	flowstat_t     fo_stats;              /* Flow statistics */
	pthread_cond_t fo_cv;                 /* Block/wakeup cv */
	pthread_mutex_t fo_lock;              /* Mutex around flowop */
	char           *fo_buf;               /* Per-flowop buffer */

	int            fo_semid_lw;           /* sem id */
	int            fo_semid_hw;           /* sem id for highwater block */
	var_integer_t  fo_highwater;          /* value of highwater paramter */
	void           *fo_idp;               /* id, for sems etc */
	hrtime_t       fo_timestamp;          /* for ratecontrol, etc... */
	int            fo_initted;            /* Set to one if initialized */
	int64_t        fo_tputbucket;         /* Throughput bucket, for limiter */
	uint64_t       fo_tputlast;           /* Throughput count, for delta's */
	
} flowop_t;

/* Flow Op Attrs */
#define FLOW_ATTR_SEQUENTIAL 0x1
#define FLOW_ATTR_RANDOM     0x2  
#define FLOW_ATTR_STRIDE     0x4
#define FLOW_ATTR_BACKWARDS  0x8
#define FLOW_ATTR_DSYNC      0x10
#define FLOW_ATTR_BLOCKING   0x20
#define FLOW_ATTR_DIRECTIO   0x40
#define FLOW_ATTR_READ       0x80
#define FLOW_ATTR_WRITE      0x100

#define FLOW_MASTER -1	    /* Declaration of thread from script */
#define FLOW_DEFINITION 0   /* Prototype definition of flowop from library */

#define FLOW_TYPES           5
#define FLOW_TYPE_GLOBAL     0  /* Rolled up statistics */
#define FLOW_TYPE_IO         1  /* Op is an I/O, reflected in iops and lat */
#define FLOW_TYPE_AIO        2  /* Op is an async I/O, reflected in iops */
#define FLOW_TYPE_SYNC       3  /* Op is a sync event */
#define FLOW_TYPE_OTHER      4  /* Op is a something else */

extern flowstat_t controlstats;

int flowop_init();
flowop_t *flowop_define(threadflow_t *, char *name, flowop_t *inherit,
    int instance, int type);
flowop_t *flowop_find(char *name);
flowop_t *flowop_find_one(char *name, int instance);
void flowop_define_barrier(void);
void flowop_find_barrier(void);
void flowoplib_usage();
int flowop_initflow(flowop_t *flowop);
int flowop_destructflow(flowop_t *flowop);
int flowoplib_init();
int flowop_delete_all(flowop_t **threadlist);
void flowop_endop(threadflow_t *threadflow, flowop_t *flowop);
void flowop_beginop(threadflow_t *threadflow, flowop_t *flowop);

#endif
