/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#ifndef _THREADFLOW_H
#define _THREADFLOW_H

#include "config.h"
#include <pthread.h>

#ifndef HAVE_CADDR_T1
//typedef char	    *caddr_t;
#endif

#ifdef LINUX_PORT
#include <linux/types.h>  /* for "caddr_t" */
#endif


#ifdef HAVE_AIO
#include <aio.h>
#endif
#ifdef HAVE_PROCFS
#include <procfs.h>
#endif
#include "vars.h"
#include "procflow.h"
#include "fileset.h"

#define AL_READ  1
#define AL_WRITE 2


#ifdef HAVE_AIO
typedef struct aiolist {
	int            al_type;
	struct aiolist *al_next;
	struct aiolist *al_worknext;
	struct aiocb64  al_aiocb;
} aiolist_t;
#endif

#define THREADFLOW_MAXFD 128
#define THREADFLOW_USEISM 0x1

typedef struct threadflow {
	char              tf_name[128];   /* Name */
	int               tf_attrs;       /* Attributes */
	int               tf_instance;    /* Instance number */
	int               tf_running;     /* Thread running indicator */
        int               tf_abort;       /* Shutdown thread */
	int               tf_utid;        /* Unique id for thread */
	struct procflow   *tf_process;    /* Back pointer to process */
	pthread_t         tf_tid;         /* Thread id */
	pthread_mutex_t   tf_lock;        /* Mutex around threadflow */
	var_integer_t     tf_instances;   /* Number of instances for this flow */
	struct threadflow *tf_next;       /* Next on proc list */
	struct flowop     *tf_ops;        /* Flowop list */
	caddr_t           tf_mem;         /* Private Memory */
	var_integer_t     tf_memsize;     /* Private Memory size */
	int               tf_fd[THREADFLOW_MAXFD + 1]; /* Thread local fd's */
	filesetentry_t    *tf_fse[THREADFLOW_MAXFD + 1]; /* Thread local files */
        int               tf_fdrotor;     /* Rotating fd within set */
	flowstat_t        tf_stats;       /* Thread statistics */
	hrtime_t          tf_stime;       /* Start time of op */
#ifdef HAVE_PROCFS
	struct prusage    tf_susage;      /* Resource usage snapshot, start */
	struct prusage    tf_eusage;      /* Resource usage snapshot, end */
#endif
	int               tf_lwpusagefd;  /* /proc lwp usage fd */
#ifdef HAVE_AIO
	aiolist_t        *tf_aiolist;     /* List of async I/Os */
#endif

} threadflow_t;

/* Thread attrs */
#define THREADFLOW_DEFAULTMEM 1024*1024LL;

threadflow_t *threadflow_define(procflow_t *, char *name, threadflow_t *inherit,
    var_integer_t instances);
threadflow_t *threadflow_find(threadflow_t *, char *);
int        threadflow_init(procflow_t *);
void       flowop_start(threadflow_t *threadflow);
void       threadflow_usage();
int        threadflow_allstarted(pid_t pid, threadflow_t *threadflow);
int        threadflow_delete_all(threadflow_t **threadlist);
void       threadflow_threadexit();

#endif
