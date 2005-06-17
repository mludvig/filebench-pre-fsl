/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>

#include <stdio.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/errno.h>
#include <signal.h>
#include <pthread.h>
#include <sys/shm.h>
#include "filebench.h"

/* IPC Hub and Simple memory allocator */

static int shmfd;
filebench_shm_t *filebench_shm = NULL;
static pthread_mutexattr_t *mutexattr = NULL;
char *null=NULL;

static int ipc_ismattach();

int
ipc_mutex_lock(pthread_mutex_t *mutex)
{
	int error;

	error = pthread_mutex_lock(mutex);

#ifdef HAVE_ROBUST_MUTEX
	if (error == EOWNERDEAD) {
		if (pthread_mutex_consistent_np(mutex) != 0) {
			filebench_log(LOG_FATAL, "mutex make consistent failed: %s",
			    strerror(error));			
			return(-1);
		}
		return(0);
	}
#endif /* HAVE_ROBUST_MUTEX */

	if (error != 0) {
		filebench_log(LOG_FATAL, "mutex lock failed: %s",
		    strerror(error));
	}

	return(error);
}

int
ipc_mutex_unlock(pthread_mutex_t *mutex)
{
	int error;

	error = pthread_mutex_unlock(mutex);

#ifdef HAVE_ROBUST_MUTEX
	if (error == EOWNERDEAD) {
		if (pthread_mutex_consistent_np(mutex) != 0) {
			filebench_log(LOG_FATAL, "mutex make consistent failed: %s",
			    strerror(error));			
			return(-1);
		}
		return(0);
	}
#endif /* HAVE_ROBUST_MUTEX */

	if (error != 0) {
		filebench_log(LOG_FATAL, "mutex unlock failed: %s",
		    strerror(error));
	}

	return(error);
}

pthread_mutexattr_t *
ipc_mutexattr(void)
{
	if (mutexattr == NULL) {
		if ((mutexattr = malloc(sizeof(pthread_mutexattr_t))) == NULL) {
			filebench_log(LOG_ERROR, "cannot alloc mutex attr");
			filebench_shutdown(1);
		}
#ifdef HAVE_PROCSCOPE_PTHREADS
		pthread_mutexattr_init(mutexattr);
		if (pthread_mutexattr_setpshared(mutexattr, 
		    PTHREAD_PROCESS_SHARED) != 0) {
			filebench_log(LOG_ERROR,
			    "cannot set mutex attr PROCESS_SHARED on this platform");
			filebench_shutdown(1);
		}
#ifdef HAVE_PTHREAD_MUTEXATTR_SETPROTOCOL
		if (pthread_mutexattr_setprotocol(mutexattr, 
		    PTHREAD_PRIO_INHERIT) != 0) {
			filebench_log(LOG_ERROR,
			    "cannot set mutex attr PTHREAD_PRIO_INHERIT on this platform");
			filebench_shutdown(1);
		}      		
#endif /* HAVE_PTHREAD_MUTEXATTR_SETPROTOCOL */
#endif /* HAVE_PROCSCOPE_PTHREADS */			
#ifdef HAVE_ROBUST_MUTEX
		if (pthread_mutexattr_setrobust_np(mutexattr, 
		    PTHREAD_MUTEX_ROBUST_NP) != 0) {
			filebench_log(LOG_ERROR,
			    "cannot set mutex attr PTHREAD_MUTEX_ROBUST_NP on this platform");
			filebench_shutdown(1);
		}      					
		if (pthread_mutexattr_settype(mutexattr, 
		    PTHREAD_MUTEX_ERRORCHECK) != 0) {
			filebench_log(LOG_ERROR,
			    "cannot set mutex attr PTHREAD_MUTEX_ERRORCHECK on this platform");
			filebench_shutdown(1);
		}      					
#endif /* HAVE_ROBUST_MUTEX */

	}
	return (mutexattr);
}

static pthread_condattr_t *condattr = NULL;

pthread_condattr_t *
ipc_condattr(void)
{
	if (condattr == NULL) {
		if ((condattr = malloc(sizeof(pthread_condattr_t))) == NULL) {
			filebench_log(LOG_ERROR, "cannot alloc cond attr");
			filebench_shutdown(1);
		}
#ifdef HAVE_PROCSCOPE_PTHREADS
		pthread_condattr_init(condattr);
		if (pthread_condattr_setpshared(condattr, 
			PTHREAD_PROCESS_SHARED) != 0) {
			filebench_log(LOG_ERROR, 
			    "cannot set cond attr PROCESS_SHARED");
			filebench_shutdown(1);
		}					
#endif /* HAVE_PROCSCOPE_PTHREADS */			
	}
	return (condattr);
}

static pthread_rwlockattr_t *rwlockattr = NULL;

pthread_rwlockattr_t *
ipc_rwlockattr(void)
{
	if (rwlockattr == NULL) {
		if ((rwlockattr = malloc(sizeof(pthread_rwlockattr_t))) == NULL) {
			filebench_log(LOG_ERROR, "cannot alloc rwlock attr");
			filebench_shutdown(1);
		}
#ifdef HAVE_PROCSCOPE_PTHREADS
		pthread_rwlockattr_init(rwlockattr);
		if (pthread_rwlockattr_setpshared(rwlockattr, 
			PTHREAD_PROCESS_SHARED) != 0) {
			filebench_log(LOG_ERROR, 
			    "cannot set rwlock attr PROCESS_SHARED");
			filebench_shutdown(1);
		}					
#endif /* HAVE_PROCSCOPE_PTHREADS */			
	}
	return (rwlockattr);
}

char *shmpath = NULL;

void
ipc_seminit()
{
	key_t key = filebench_shm->semkey;
	int semid;

	/* Already done? */
	if (filebench_shm->seminit)
		return;

	if ((semid = semget(key, FILEBENCH_NSEMS, IPC_CREAT |
		 S_IRUSR | S_IWUSR)) == -1) {
		filebench_log(LOG_ERROR, 
		    "could not create sysv semaphore set (need to increase sems?): %s", 
		    strerror(errno));
		exit(1);
	}
	return;
}

void
ipc_init()
{
	int semid;

	filebench_shm_t *buf = malloc(MB);
	int i;
	key_t key;
	caddr_t c1;
	caddr_t c2;

#ifdef HAVE_MKSTEMP
	shmpath = (char *)"/var/tmp/fbenchXXXXXX";
	shmfd = mkstemp(shmpath);
#else
	shmpath = tempnam("/var/tmp", "fbench");
	shmfd   = open(shmpath, O_CREAT | O_RDWR | O_TRUNC, 0666);
#endif

	if (shmfd  < 0) {
		filebench_log(LOG_FATAL, "Cannot open shm %s: %s",
		    shmpath,
		    strerror(errno));
		exit(1);
	}

	lseek(shmfd, sizeof(filebench_shm_t), SEEK_SET);
	if (write(shmfd, buf, MB) != MB) {
		filebench_log(LOG_FATAL, 
		    "Cannot allocate shm: %s", strerror(errno));
		exit(1);
	}
	

#ifdef NEVER
	for (i = 0; i < sizeof(filebench_shm_t); i += MB) {
		if (write(shmfd, buf, MB) != MB) {
			filebench_log(LOG_FATAL, 
			    "Cannot allocate shm: %s", strerror(errno));
			exit(1);
		}
	}
#endif

	if ((filebench_shm = (filebench_shm_t *)mmap(0, sizeof(filebench_shm_t), 
		PROT_READ | PROT_WRITE,
		MAP_SHARED, shmfd, 0)) == NULL) {
		filebench_log(LOG_FATAL, "Cannot mmap shm");
		exit(1);
	}


	c1 = (caddr_t)filebench_shm;
	c2 = (caddr_t)&filebench_shm->marker;

	memset(filebench_shm, 0, c2 - c1);
	filebench_shm->epoch = gethrtime();
	filebench_shm->debug_level = 2;
	filebench_shm->string_ptr = &filebench_shm->strings[0];
	filebench_shm->shm_ptr = (char *)filebench_shm->shm_addr;
	filebench_shm->path_ptr = &filebench_shm->filesetpaths[0];

	/* Setup mutexes for object lists */
	pthread_mutex_init(&filebench_shm->fileobj_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->fileset_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->procflow_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->threadflow_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->flowop_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->msg_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->eventgen_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->malloc_lock, ipc_mutexattr());
	pthread_mutex_init(&filebench_shm->ism_lock, ipc_mutexattr());
	pthread_cond_init(&filebench_shm->eventgen_cv, ipc_condattr());
	pthread_rwlock_init(&filebench_shm->flowop_find_lock, ipc_rwlockattr());
	pthread_rwlock_init(&filebench_shm->run_lock, ipc_rwlockattr());
	pthread_rwlock_rdlock(&filebench_shm->run_lock);

	ipc_mutex_lock(&filebench_shm->ism_lock);

	/* Create semaphore */
	if ((key = ftok(shmpath, 1)) < 0) {
		filebench_log(LOG_ERROR, "cannot create sem: %s", 
		    strerror(errno));
		exit(1);
	}

	if ((semid = semget(key, 0, 0)) != -1) {
#define HAVE_SEM_RMID
#ifdef HAVE_SEM_RMID
		semctl(semid, 0, IPC_RMID);
#endif
	}

	
	filebench_shm->semkey = key;
	filebench_shm->log_fd = -1;
	filebench_shm->dump_fd = -1;
	filebench_shm->eventgen_hz = 0;
	filebench_shm->shm_id = -1;

	free(buf);
}

int
ipc_cleanup()
{
	unlink(shmpath);
	
}

int
ipc_attach(caddr_t shmaddr)
{
	if ((shmfd = open(shmpath, O_RDWR, 0666)) < 0) {
		filebench_log(LOG_ERROR, "Cannot open shm");
		return(-1);
	}

	if ((filebench_shm = (filebench_shm_t *)mmap(shmaddr, sizeof(filebench_shm_t), 
		PROT_READ | PROT_WRITE,
		MAP_SHARED | MAP_FIXED, shmfd, 0)) == NULL) {
		filebench_log(LOG_ERROR, "Cannot mmap shm");
		return(-1);
	}

	filebench_log(LOG_DEBUG_IMPL, "addr = %zx", filebench_shm);

	return(0);
}

int filebench_sizes[] = {
	FILEBENCH_NFILEOBJS,
	FILEBENCH_NPROCFLOWS,
	FILEBENCH_NTHREADFLOWS,
	FILEBENCH_NFLOWOPS,
	FILEBENCH_NVARS,
	FILEBENCH_NVARS,
	FILEBENCH_NVARS,
	FILEBENCH_NVARS,
        FILEBENCH_NFILESETENTRIES};

char *
ipc_malloc(int type)
{
	int i;
	int max = filebench_sizes[type];

	ipc_mutex_lock(&filebench_shm->malloc_lock);

        for (i = 0; filebench_shm->bitmap[type][i] == 1; i++) {
		if (i == max)
			goto ipc_malloc_outofmemory;
	}
	filebench_shm->bitmap[type][i] = 1;


	switch (type) {
	case FILEBENCH_FILEOBJ:
		memset((char *)&filebench_shm->fileobj[i], 0, sizeof(fileobj_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->fileobj[i]);
		
	case FILEBENCH_FILESET:
		memset((char *)&filebench_shm->fileset[i], 0, sizeof(fileset_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->fileset[i]);
		
	case FILEBENCH_FILESETENTRY:
		memset((char *)&filebench_shm->filesetentry[i], 0, sizeof(filesetentry_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->filesetentry[i]);
		
	case FILEBENCH_PROCFLOW:
		memset((char *)&filebench_shm->procflow[i], 0, sizeof(procflow_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->procflow[i]);

	case FILEBENCH_THREADFLOW:
		memset((char *)&filebench_shm->threadflow[i], 0, sizeof(threadflow_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->threadflow[i]);

	case FILEBENCH_FLOWOP:
		memset((char *)&filebench_shm->flowop[i], 0, sizeof(flowop_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->flowop[i]);
	
	case FILEBENCH_INTEGER:
		filebench_shm->integer_ptrs[i] = NULL;
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->integer_ptrs[i]);
	
	case FILEBENCH_STRING:
		filebench_shm->string_ptrs[i] = NULL;
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->string_ptrs[i]);
	
	case FILEBENCH_VARIABLE:
		memset((char *)&filebench_shm->var[i], 0, sizeof(var_t));
		ipc_mutex_unlock(&filebench_shm->malloc_lock);
		return((char *)&filebench_shm->var[i]);
	}

ipc_malloc_outofmemory:
	filebench_log(LOG_ERROR, "Out of shared memory (%d)!", type);
	ipc_mutex_unlock(&filebench_shm->malloc_lock);
	return(NULL);
}

void
ipc_free(int type, char *addr)
{
	int item;
	caddr_t base;
	size_t offset;
	size_t size;

	if (addr == NULL) {
		filebench_log(LOG_ERROR, "Freeing type %d %zx", type, addr);
		return;
	}

	switch (type) {
	case FILEBENCH_FILEOBJ:
		base = (caddr_t)&filebench_shm->fileobj[0];
		size = sizeof(fileobj_t);
		break;
		
	case FILEBENCH_FILESET:
		base = (caddr_t)&filebench_shm->fileset[0];
		size = sizeof(fileset_t);
		break;
		
	case FILEBENCH_FILESETENTRY:
		base = (caddr_t)&filebench_shm->filesetentry[0];
		size = sizeof(filesetentry_t);
		break;
		
	case FILEBENCH_PROCFLOW:
		base = (caddr_t)&filebench_shm->procflow[0];
		size = sizeof(procflow_t);
		break;

	case FILEBENCH_THREADFLOW:
		base = (caddr_t)&filebench_shm->threadflow[0];
		size = sizeof(threadflow_t);
		break;

	case FILEBENCH_FLOWOP:
		base = (caddr_t)&filebench_shm->flowop[0];
		size = sizeof(flowop_t);
		break;
	
	case FILEBENCH_INTEGER:
		base = (caddr_t)&filebench_shm->integer_ptrs[0];
		size = sizeof(caddr_t);
		break;
	
	case FILEBENCH_STRING:
		base = (caddr_t)&filebench_shm->string_ptrs[0];
		size = sizeof(caddr_t);
		break;
	
	case FILEBENCH_VARIABLE:
		base = (caddr_t)&filebench_shm->var[0];
		size = sizeof(var_t);
		break;
	}
	
	offset = ((size_t)addr - (size_t)base);
	item = offset / size;

	ipc_mutex_lock(&filebench_shm->malloc_lock);
	filebench_shm->bitmap[type][item] = 0; 
	ipc_mutex_unlock(&filebench_shm->malloc_lock);
	return;
}

/* Allocate string */
char *
ipc_stralloc(char *string)
{
	char *allocstr = filebench_shm->string_ptr;

	filebench_shm->string_ptr += strlen(string) + 1;
	strncpy(allocstr, string, strlen(string));

	return(allocstr);
}

/* Allocate fileset path */
char *
ipc_pathalloc(char *path)
{
	char *allocpath = filebench_shm->path_ptr;

	filebench_shm->path_ptr += strlen(path) + 1;

/*
	if ((filebench_shm->path_ptr - &filebench_shm->filesetpaths[0]) >
	    FILEBENCH_NFILESETENTRIES * FSE_MAXPATHLEN) {
		filebench_log(LOG_ERROR, "Out of fileset path memory");
		return(NULL);
	}
*/

	strncpy(allocpath, path, strlen(path));

	return(allocpath);
}

/*
 * This is a limited functionallity allocator for strings - it can only
 * free all strings at once (to avoid fragmentation
 */
void
ipc_freepaths()
{
	filebench_shm->path_ptr = &filebench_shm->filesetpaths[0];
}

int
ipc_semidalloc(void)
{
	int semid;

	for (semid = 0; filebench_shm->semids[semid] == 1; semid++)
		;
	if (semid == FILEBENCH_NSEMS) {
		filebench_log(LOG_ERROR, 
		    "Out of semaphores, increase system tunable limit");
		filebench_shutdown(1);
	}
	filebench_shm->semids[semid] = 1;
	return(semid);
}

int
ipc_semidfree(int semid)
{
	filebench_shm->semids[semid] = 0;
}

/* Create a pool of shared memory to fit the per-thread allocations */
int
ipc_ismcreate(size_t size)
{
#ifdef HAVE_SHM_SHARE_MMU
	int flag = SHM_SHARE_MMU;
#else
	int flag = 0;
#endif /* HAVE_SHM_SHARE_MMU */

	/* Already done? */
	if (filebench_shm->shm_id != -1)
		return(0);

	filebench_log(LOG_VERBOSE, 
	    "Creating %zd bytes of ISM Shared Memory...", size);

	filebench_shm->shm_id = shmget(0, size, IPC_CREAT | 0666);

	if ((filebench_shm->shm_addr = (caddr_t )shmat(filebench_shm->shm_id,
		    0, flag)) == (void *)-1) {
		filebench_log(LOG_ERROR,
		    "Failed to allocate %zd bytes of ISM shared memory", size);
		return(-1);
	}

	filebench_shm->shm_ptr = (char *)filebench_shm->shm_addr;

	filebench_log(LOG_VERBOSE, 
	    "Allocated %zd bytes of ISM Shared Memory... at %zx",
	    size, filebench_shm->shm_addr);

	/* Locked until allocated to block allocs */
	ipc_mutex_unlock(&filebench_shm->ism_lock);

	return(0);
}

/* Per addr space ism */
int ism_attached = 0;

/* Attach to shared memory */
static int
ipc_ismattach()
{
#ifdef HAVE_SHM_SHARE_MMU
	int flag = SHM_SHARE_MMU;
#else
	int flag = 0;
#endif /* HAVE_SHM_SHARE_MMU */


        if (ism_attached)
		return(0);

	/* Does it exist? */
	if (filebench_shm->shm_id == 999)
		return(0);

	if (shmat(filebench_shm->shm_id,
		    filebench_shm->shm_addr, flag) == NULL)
		return(-1);

	ism_attached = 1;

	return(0);
}

/* Allocate from ISM */
char *
ipc_ismmalloc(size_t size)
{
	char *allocstr;

	ipc_mutex_lock(&filebench_shm->ism_lock);

	/* Map in shared memory */
	ipc_ismattach();

	allocstr = filebench_shm->shm_ptr;

	filebench_shm->shm_ptr += size;
	filebench_shm->shm_allocated += size;

	ipc_mutex_unlock(&filebench_shm->ism_lock);

	return(allocstr);
}

void
ipc_ismdelete()
{
	if (filebench_shm->shm_id == -1)
		return;

	filebench_log(LOG_VERBOSE, "Deleting ISM...");

	ipc_mutex_lock(&filebench_shm->ism_lock);
	shmctl(filebench_shm->shm_id, IPC_RMID, 0);
	filebench_shm->shm_ptr = (char *)filebench_shm->shm_addr;
	filebench_shm->shm_id = -1;
	filebench_shm->shm_allocated = 0;

	return;
}
