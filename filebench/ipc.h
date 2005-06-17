/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#ifndef FBIPC_H
#define FBIPC_H

#include <config.h>
#include <pthread.h>

#include "procflow.h"
#include "threadflow.h"
#include "fileobj.h"
#include "fileset.h"
#include "flowop.h"

#define FILEBENCH_MEMSIZE 4096
#define FILEBENCH_NFILEOBJS FILEBENCH_MEMSIZE
#define FILEBENCH_NFILESETS FILEBENCH_MEMSIZE
#define FILEBENCH_NFILESETENTRIES (1024 * 1024)
#define FILEBENCH_NPROCFLOWS FILEBENCH_MEMSIZE
#define FILEBENCH_NTHREADFLOWS 64 * FILEBENCH_MEMSIZE
#define FILEBENCH_NFLOWOPS 64 * FILEBENCH_MEMSIZE
#define FILEBENCH_NVARS FILEBENCH_MEMSIZE
#define FILEBENCH_STRINGMEMORY FILEBENCH_NVARS * 128
#define FILEBENCH_MAXBITMAP FILEBENCH_NFILESETENTRIES

#define FILEBENCH_FILEOBJ    0
#define FILEBENCH_PROCFLOW   1
#define FILEBENCH_THREADFLOW 2
#define FILEBENCH_FLOWOP     3
#define FILEBENCH_INTEGER    4
#define FILEBENCH_STRING     5
#define FILEBENCH_VARIABLE   6
#define FILEBENCH_FILESET    7
#define FILEBENCH_FILESETENTRY 8
#define FILEBENCH_TYPES      9


#define FILEBENCH_NSEMS 128

typedef struct filebench_shm {

	pthread_mutex_t      fileobj_lock;
	pthread_mutex_t      fileset_lock;
	pthread_mutex_t      procflow_lock;
	pthread_mutex_t      threadflow_lock;
	pthread_mutex_t      flowop_lock;
	pthread_mutex_t      msg_lock;
	pthread_mutex_t      malloc_lock;
	pthread_mutex_t      ism_lock;
	pthread_rwlock_t     run_lock;
	pthread_rwlock_t     flowop_find_lock;

	char         *string_ptr;
	char         *path_ptr;
	fileobj_t    *filelist;
	fileset_t    *filesetlist;
	flowop_t     *flowoplist;
	procflow_t   *proclist;
	var_t        *var_list;
	var_t        *var_dyn_list;
	int          debug_level;
	hrtime_t     epoch;
	hrtime_t     starttime;
        int          bequiet;
	key_t        semkey;
	int          seminit;
	int          semid_seq;
	int          utid;
	int          log_fd;
	int          dump_fd;
	char         dump_filename[MAXPATHLEN];
	pthread_mutex_t eventgen_lock;
	pthread_cond_t eventgen_cv;
	int          eventgen_hz;
	int          eventgen_q;
	char         fscriptname[1024];
	int          shm_id;
	size_t       shm_required;
	size_t       shm_allocated;
	caddr_t      shm_addr;
	char         *shm_ptr;
	int          allrunning;
	int          f_abort;

	int          marker;

	fileobj_t    fileobj[FILEBENCH_NFILEOBJS];
	fileset_t    fileset[FILEBENCH_NFILESETS];
	filesetentry_t filesetentry[FILEBENCH_NFILESETENTRIES];
	char         filesetpaths[FILEBENCH_NFILESETENTRIES * FSE_MAXPATHLEN];
	procflow_t   procflow[FILEBENCH_NPROCFLOWS];
	threadflow_t threadflow[FILEBENCH_NTHREADFLOWS];
	flowop_t     flowop[FILEBENCH_NFLOWOPS];
	var_t        var[FILEBENCH_NVARS];
	vinteger_t   integer_ptrs[FILEBENCH_NVARS];
	char         *string_ptrs[FILEBENCH_NVARS];
	char         strings[FILEBENCH_STRINGMEMORY];
	char         semids[FILEBENCH_NSEMS];
	int          bitmap[FILEBENCH_TYPES][FILEBENCH_MAXBITMAP];

} filebench_shm_t;

extern char *shmpath;

void ipc_init();
char *ipc_malloc(int type);
void ipc_free(int type, char *addr);
int ipc_attach();
pthread_mutexattr_t *ipc_mutexattr(void);
pthread_condattr_t *ipc_condattr(void);
pthread_rwlockattr_t *ipc_rwlockattr(void);
int ipc_semidalloc(void);
int ipc_semidfree(int semid);
char *ipc_stralloc(char *string);
char *ipc_pathalloc(char *string);
int ipc_mutex_lock(pthread_mutex_t *mutex);
int ipc_mutex_unlock(pthread_mutex_t *mutex);
void ipc_seminit();
char *ipc_ismmalloc(size_t size);
int ipc_ismcreate(size_t size);
void ipc_ismdelete();
int ipc_cleanup();

extern filebench_shm_t *filebench_shm;

#endif
