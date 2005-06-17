/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>

#include <sys/types.h>
#ifdef HAVE_SYS_ASYNCH_H
#include <sys/asynch.h>
#endif
#include <sys/ipc.h>
#include <sys/sem.h>
#include <sys/errno.h>
#include <sys/time.h>
#include <inttypes.h>
#include <fcntl.h>

#ifdef HAVE_UTILITY_H
#include <utility.h>
#endif /* HAVE_UTILITY_H */

#ifdef HAVE_AIO
#include <aio.h>
#endif /* HAVE_AIO */

#ifdef HAVE_LIBAIO_H
#include <libaio.h>
#endif /* HAVE_LIBAIO_H */

#ifdef HAVE_SYS_ASYNC_H
#include <sys/asynch.h>
#endif /* HAVE_SYS_ASYNC_H */

#ifdef HAVE_AIO_H
#include <aio.h>
#endif /* HAVE_AIO_H */

#ifndef HAVE_UINT_T
#define uint_t unsigned int
#endif /* HAVE_UINT_T */

#ifndef HAVE_AIOCB64_T
#define aiocb64 aiocb
#endif /* HAVE_AIOCB64_T */

#include "filebench.h"
#include "flowop.h"
#include "fileset.h"

static int flowoplib_init_generic(flowop_t *flowop);
static int flowoplib_destruct_generic(flowop_t *flowop);
static int flowoplib_fdnum(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_write(threadflow_t *threadflow, flowop_t *flowop);
#ifdef HAVE_AIO
static int flowoplib_aiowrite(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_aiowait(threadflow_t *threadflow, flowop_t *flowop);
#endif
static int flowoplib_read(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_block_init(flowop_t *flowop);
static int flowoplib_block(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_wakeup(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_hog(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_delay(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_sempost(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_sempost_init(flowop_t *flowop);
static int flowoplib_semblock(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_semblock_init(flowop_t *flowop);
static int flowoplib_semblock_destruct(flowop_t *flowop);
static int flowoplib_eventlimit(threadflow_t *, flowop_t *flowop);
static int flowoplib_eventlimit_destruct(flowop_t *flowop);
static int flowoplib_bwlimit(threadflow_t *, flowop_t *flowop);
static int flowoplib_iopslimit(threadflow_t *, flowop_t *flowop);
static int flowoplib_opslimit(threadflow_t *, flowop_t *flowop);
static int flowoplib_openfile(threadflow_t *, flowop_t *flowop);
static int flowoplib_openfile_common(threadflow_t *, flowop_t *flowop, int fd);
static int flowoplib_createfile(threadflow_t *, flowop_t *flowop);
static int flowoplib_closefile(threadflow_t *, flowop_t *flowop);
static int flowoplib_fsync(threadflow_t *, flowop_t *flowop);
static int flowoplib_readwholefile(threadflow_t *, flowop_t *flowop);
static int flowoplib_writewholefile(threadflow_t *, flowop_t *flowop);
static int flowoplib_appendfile(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_appendfilerand(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_deletefile(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_statfile(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_finishoncount(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_finishonbytes(threadflow_t *threadflow, flowop_t *flowop);
static int flowoplib_fsyncset(threadflow_t *threadflow, flowop_t *flowop);

struct flowoplib {
	int    fl_type;
	int    fl_attrs;
	char   *fl_name;
	int    (*fl_init)();
	int    (*fl_func)();
	int    (*fl_destruct)();
};

struct flowoplib flowoplib_funcs[] = {
	FLOW_TYPE_IO, FLOW_ATTR_WRITE, "write",flowoplib_init_generic,
	flowoplib_write, flowoplib_destruct_generic,
	FLOW_TYPE_IO, FLOW_ATTR_READ, "read",flowoplib_init_generic,
	flowoplib_read, flowoplib_destruct_generic,
#ifdef HAVE_AIO
	FLOW_TYPE_AIO, FLOW_ATTR_WRITE,   "aiowrite",flowoplib_init_generic, 
	flowoplib_aiowrite, flowoplib_destruct_generic,
	FLOW_TYPE_AIO, 0, "aiowait",flowoplib_init_generic,
	flowoplib_aiowait, flowoplib_destruct_generic,
#endif
	FLOW_TYPE_SYNC, 0, "block",flowoplib_block_init, 
	flowoplib_block, flowoplib_destruct_generic,
	FLOW_TYPE_SYNC, 0, "wakeup",flowoplib_init_generic,
	flowoplib_wakeup, flowoplib_destruct_generic,
	FLOW_TYPE_SYNC, 0, "semblock",flowoplib_semblock_init,
	flowoplib_semblock, flowoplib_semblock_destruct,
	FLOW_TYPE_SYNC, 0, "sempost",flowoplib_sempost_init,
	flowoplib_sempost, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "hog",flowoplib_init_generic, 
	flowoplib_hog, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "delay",flowoplib_init_generic,
	flowoplib_delay, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "eventlimit",flowoplib_init_generic,
	flowoplib_eventlimit, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "bwlimit",flowoplib_init_generic,
	flowoplib_bwlimit, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "iopslimit",flowoplib_init_generic,
	flowoplib_iopslimit, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "opslimit",flowoplib_init_generic,
	flowoplib_opslimit, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "finishoncount",flowoplib_init_generic,
	flowoplib_finishoncount, flowoplib_destruct_generic,
	FLOW_TYPE_OTHER, 0, "finishonbytes",flowoplib_init_generic,
	flowoplib_finishonbytes, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "openfile",flowoplib_init_generic,
	flowoplib_openfile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "createfile",flowoplib_init_generic,
	flowoplib_createfile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "closefile",flowoplib_init_generic,
	flowoplib_closefile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "fsync",flowoplib_init_generic,
	flowoplib_fsync, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "fsyncset",flowoplib_init_generic,
	flowoplib_fsyncset, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "statfile",flowoplib_init_generic,
	flowoplib_statfile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, FLOW_ATTR_READ, "readwholefile",flowoplib_init_generic,
	flowoplib_readwholefile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, FLOW_ATTR_WRITE, "appendfile",flowoplib_init_generic,
	flowoplib_appendfile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, FLOW_ATTR_WRITE, "appendfilerand",flowoplib_init_generic,
	flowoplib_appendfilerand, flowoplib_destruct_generic,
	FLOW_TYPE_IO, 0, "deletefile",flowoplib_init_generic,
	flowoplib_deletefile, flowoplib_destruct_generic,
	FLOW_TYPE_IO, FLOW_ATTR_WRITE, "writewholefile",flowoplib_init_generic,
	flowoplib_writewholefile, flowoplib_destruct_generic
};

int
flowoplib_init()
{
	flowop_t *flowop;
	int nops = sizeof(flowoplib_funcs) / sizeof(struct flowoplib);
	int i;
	struct flowoplib *fl;

	for (i = 0; i < nops; i++) {

		fl = &flowoplib_funcs[i];
		
		if ((flowop = flowop_define(NULL, 
		    fl->fl_name, NULL, 0, fl->fl_type)) == 0) {
			filebench_log(LOG_ERROR,
			    "failed to create flowop %s\n",
			    fl->fl_name);
			filebench_shutdown(1);
		}

		flowop->fo_func = fl->fl_func;
		flowop->fo_init = fl->fl_init;
		flowop->fo_destruct = fl->fl_destruct;
		flowop->fo_attrs = fl->fl_attrs;
	}
}

static int 
flowoplib_init_generic(flowop_t *flowop)
{
	ipc_mutex_unlock(&flowop->fo_lock);
	return(0);
}

static int 
flowoplib_destruct_generic(flowop_t *flowop)
{
	return(0);
}

static int 
flowoplib_fileattrs(flowop_t *flowop)
{
	int attrs = 0;

	if (*flowop->fo_directio)
		attrs |= FLOW_ATTR_DIRECTIO;

	if (*flowop->fo_dsync)
		attrs |= FLOW_ATTR_DSYNC;

	return(attrs);	
}

/* find a file descriptor */
int
flowoplib_fdnum(threadflow_t *threadflow, flowop_t *flowop)
{
	/* If the script sets the fd explicitly */
	if (flowop->fo_fdnumber > 0) {
		return(flowop->fo_fdnumber);
	}

	/* If the flowop defaults to persistent fd */
	if (!integer_isset(flowop->fo_rotatefd))
		return(flowop->fo_fdnumber);

	/* Rotate the fd on each flowop invocation */
	if (*(flowop->fo_fileset->fs_entries) > (THREADFLOW_MAXFD / 2)) {
		filebench_log(LOG_ERROR,
			"Out of file descriptors in flowop %s"
			" (too many files : %d",
			flowop->fo_name,
			*(flowop->fo_fileset->fs_entries));
		return(-1);
	}

	/* First time around */
	if (threadflow->tf_fdrotor == 0)
		threadflow->tf_fdrotor = THREADFLOW_MAXFD;

	/* One fd for every file in the set */
	if (*(flowop->fo_fileset->fs_entries) ==
		(THREADFLOW_MAXFD - threadflow->tf_fdrotor))
		threadflow->tf_fdrotor = THREADFLOW_MAXFD;
		

	threadflow->tf_fdrotor--;
	filebench_log(LOG_DEBUG_IMPL, "selected fd = %d", threadflow->tf_fdrotor);
	return(threadflow->tf_fdrotor);
}

/* emulate posix read/pread */
static int
flowoplib_read(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	size_t divisor;
	int ret;
	vinteger_t wss;
	long memsize, round;
	int fd;
	int filedesc;

	if (flowop->fo_fileset || flowop->fo_fdnumber) {
		fd = flowoplib_fdnum(threadflow, flowop);

		if (fd == -1)
			return(-1);

		if (threadflow->tf_fd[fd] == 0) {
			flowoplib_openfile_common(threadflow, flowop, fd);
			filebench_log(LOG_DEBUG_IMPL, "read opened file %s",
			    threadflow->tf_fse[fd]->fse_path);
		}
		filedesc = threadflow->tf_fd[fd];
		if (*flowop->fo_wss == 0)
			wss = threadflow->tf_fse[fd]->fse_size;
		else
			wss = *flowop->fo_wss;
	} else {
		if (flowop->fo_file == NULL) {
			filebench_log(LOG_ERROR, "flowop NULL file");
			return(-1);
		}	
		if (flowop->fo_fd < 0)
			flowop->fo_fd = fileobj_open(flowop->fo_file,
			    flowoplib_fileattrs(flowop));
		
		if (flowop->fo_fd < 0) {
			filebench_log(LOG_ERROR, "failed to open file %s", 
			    flowop->fo_file->fo_name);
			return(-1);
		}
		filedesc = flowop->fo_fd;
		if (*flowop->fo_wss == 0)
			wss = *flowop->fo_file->fo_size;
		else
			wss = *flowop->fo_wss;
	}

	if (*flowop->fo_wss == 0)
		wss = *flowop->fo_file->fo_size;
	else
		wss = *flowop->fo_wss;


	if (*flowop->fo_iosize == 0) {
		filebench_log(LOG_ERROR, "zero iosize for thread %s", 
		    flowop->fo_name);
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);

	if (*flowop->fo_random) {

		offset = filebench_randomno64(wss , *flowop->fo_iosize);
		flowop_beginop(threadflow, flowop);
		if ((ret = pread64(filedesc,
			    threadflow->tf_mem + memoffset, 
			    *flowop->fo_iosize, offset)) == -1) {
			flowop_endop(threadflow, flowop);
			filebench_log(LOG_ERROR, 
			    "read file %s failed, offset %lld memoffset %zd: %s",
			    flowop->fo_file->fo_name,
			    offset, memoffset, strerror(errno));
			flowop_endop(threadflow, flowop);
			return(-1);
		}
		flowop_endop(threadflow, flowop);

		if ((ret == 0))
			lseek(filedesc, 0, SEEK_SET);

	} else {
		flowop_beginop(threadflow, flowop);
		if ((ret = read(filedesc, threadflow->tf_mem + memoffset, 
			    *flowop->fo_iosize)) == -1) {
			filebench_log(LOG_ERROR, 
			    "read file %s failed, memoffset %zd: %s",
			    flowop->fo_file->fo_name,
			    memoffset, strerror(errno));
			flowop_endop(threadflow, flowop);
			return(-1);
		}
		flowop_endop(threadflow, flowop);

		if ((ret == 0))
			lseek(filedesc, 0, SEEK_SET);
	}    

	return(0);
}

#ifdef HAVE_AIO

static aiolist_t *
aio_allocate(flowop_t *flowop)
{
	aiolist_t *aiolist;

	if ((aiolist = malloc(sizeof(aiolist_t))) == NULL) {
		filebench_log(LOG_ERROR, "malloc aiolist failed");
		filebench_shutdown(1);
	}
	
	/* Add to list */
	if (flowop->fo_thread->tf_aiolist == NULL) {
		flowop->fo_thread->tf_aiolist = aiolist;
		aiolist->al_next = NULL;
	} else {
		aiolist->al_next = flowop->fo_thread->tf_aiolist;
		flowop->fo_thread->tf_aiolist = aiolist;
	}
	return(aiolist);
}

static int
aio_deallocate(threadflow_t *threadflow, flowop_t *flowop, struct aiocb64 *aiocb)
{
	aiolist_t *aiolist = flowop->fo_thread->tf_aiolist;
	aiolist_t *previous = NULL;
	aiolist_t *match = NULL;
	struct aiocb64 *a;

	if (aiocb == NULL) {
		filebench_log(LOG_ERROR, "null aiocb deallocate");
		return(0);
	}

	while (aiolist) {
		if (aiocb == &(aiolist->al_aiocb)) {
			match = aiolist;
			break;
		}
		previous = aiolist;
		aiolist = aiolist->al_next;
	}

	if (match == NULL)
		return(-1);

	/* Remove from the list */
	if (previous) {
		previous->al_next = match->al_next;
	} else {
		flowop->fo_thread->tf_aiolist = match->al_next;
	}

	return(0);
}

/* emulate posix aiowrite */
static int
flowoplib_aiowrite(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	struct aiocb64 *aiocb;
	aiolist_t *aiolist;
	vinteger_t wss;
	long memsize, round;
	int fd;
	int filedesc;

	if (flowop->fo_fileset || flowop->fo_fdnumber) {
		fd = flowoplib_fdnum(threadflow, flowop);

		if (fd == -1)
			return(-1);

		if (threadflow->tf_fd[fd] == 0) {
			flowoplib_openfile_common(threadflow, flowop, fd);
			filebench_log(LOG_DEBUG_IMPL, "writefile opened file %s",
			    threadflow->tf_fse[fd]->fse_path);
		}
		filedesc = threadflow->tf_fd[fd];
		if (*flowop->fo_wss == 0)
			wss = threadflow->tf_fse[fd]->fse_size;
		else
			wss = *flowop->fo_wss;
	} else {
		if (flowop->fo_file == NULL) {
			filebench_log(LOG_ERROR, "flowop NULL file");
			return(-1);
		}	
		if (flowop->fo_fd < 0)
			flowop->fo_fd = fileobj_open(flowop->fo_file,
			    flowoplib_fileattrs(flowop));
		
		if (flowop->fo_fd < 0) {
			filebench_log(LOG_ERROR, "failed to open file %s", 
			    flowop->fo_file->fo_name);
			return(-1);
		}
		filedesc = flowop->fo_fd;
		if (*flowop->fo_wss == 0)
			wss = *flowop->fo_file->fo_size;
		else
			wss = *flowop->fo_wss;
	}

	if (*flowop->fo_iosize == 0) {
		filebench_log(LOG_ERROR, "zero iosize for thread %s", 
		    flowop->fo_name);
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);

	if (*flowop->fo_random) {

		offset = filebench_randomno64(wss , *flowop->fo_iosize);

		aiolist = aio_allocate(flowop);
		aiolist->al_type = AL_WRITE;
		aiocb = &aiolist->al_aiocb;

		aiocb->aio_fildes = filedesc;
		aiocb->aio_buf = threadflow->tf_mem + memoffset;
		aiocb->aio_nbytes = *flowop->fo_iosize;
		aiocb->aio_offset = offset;


		filebench_log(LOG_DEBUG_IMPL,
			      "aio fd=%d, bytes=%lld, offset=%lld",
			      filedesc, *flowop->fo_iosize, offset);
		
		flowop_beginop(threadflow, flowop);
		if (aio_write64(aiocb) < 0) {
			filebench_log(LOG_ERROR, "aiowrite failed: %s",
			    strerror(errno));
			filebench_shutdown(1);
		}
		flowop_endop(threadflow, flowop);
	} else {
		return(-1);
	}

	return(0);
}



#define MAXREAP 4096

/* emulate posix aiowait */
static int
flowoplib_aiowait(threadflow_t *threadflow, flowop_t *flowop)
{
	struct aiocb64 aiocb;
	struct aiocb64 **worklist;
	aiolist_t *aiolist = flowop->fo_thread->tf_aiolist;
	aiolist_t *aio = aiolist;
	int i = 0;
	int uncompleted = 0;
	int zone3;
	uint_t ncompleted = 0;
	int zone4;
	uint_t todo;
	struct timespec timeout;
	int zone1;
	int result;
	int zone2;
	int inprogress;
	int reaped;
	
	worklist = calloc(MAXREAP, sizeof(struct aiocb64 *));

	/* Count the list of pending aios */
	while (aio) {
		uncompleted++;
		aio = aio->al_next;
	}

	do {

		/* Wait for half of the outstanding requests */
		timeout.tv_sec = 1;
		timeout.tv_nsec = 0;
		
		if (uncompleted > MAXREAP)
			todo = MAXREAP;
		else
			todo = uncompleted / 2;
		
		if (todo == 0)
		        todo = 1;
		
		flowop_beginop(threadflow, flowop);

#ifdef HAVE_AIOWAITN
		if (((result = aio_waitn64((struct aiocb64 **)worklist,
				MAXREAP, &todo, &timeout)) == -1) &&
		    errno && (errno != ETIME)) {
			filebench_log(LOG_ERROR,
			    "aiowait failed: %s, outstanding = %d, ncompleted = %d ",
			    strerror(errno), uncompleted, todo);
		}

		ncompleted = todo;
		/* Take the  completed I/Os from the list */
		inprogress = 0;
		for (i = 0; i < ncompleted; i++) {
			if ((aio_return64(worklist[i]) == -1) && (errno == EINPROGRESS)) {
				inprogress++;
				continue;
			}
			if (aio_deallocate(threadflow, flowop, worklist[i]) < 0) {
				filebench_log(LOG_ERROR, "Could not remove aio from list ");
				flowop_endop(threadflow, flowop);
				return(-1);
			}
		}

		uncompleted -= ncompleted;
		uncompleted += inprogress;

#else

		for (ncompleted = 0, inprogress = 0, aio = flowop->fo_thread->tf_aiolist;
		     ncompleted < todo, aio != NULL;
		     aio = aio->al_next) {
		
			result = aio_error64(&aio->al_aiocb);
			
			if (result == EINPROGRESS) {
				inprogress++;
				continue;
			}
			
			if ((aio_return64(&aio->al_aiocb) == -1) || result) {
				filebench_log(LOG_ERROR, "aio failed: %s", strerror(result));
				continue;
			}

			ncompleted++;
			
			if (aio_deallocate(threadflow, flowop, &aio->al_aiocb) < 0) {
				filebench_log(LOG_ERROR, "Could not remove aio from list ");
				flowop_endop(threadflow, flowop);
				return(-1);
			}
		}

		uncompleted -= ncompleted;

#endif
		filebench_log(LOG_DEBUG_SCRIPT,
		    "aio2 completed %d ios, uncompleted = %d, inprogress = %d",
		    ncompleted, uncompleted, inprogress);
		
	} while (uncompleted > MAXREAP);
	
	flowop_endop(threadflow, flowop);
	
	free(worklist);
	
	return(0);
}

#endif /* HAVE_AIO */

/* block */
static int 
flowoplib_block_init(flowop_t *flowop)
{
	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d block init address %zx", 
	    flowop->fo_name, flowop->fo_instance, &flowop->fo_cv);
	pthread_cond_init(&flowop->fo_cv, ipc_condattr());
	ipc_mutex_unlock(&flowop->fo_lock);
}

static int
flowoplib_block(threadflow_t *threadflow, flowop_t *flowop)
{
	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d blocking at address %zx", 
	    flowop->fo_name, flowop->fo_instance, &flowop->fo_cv);
	ipc_mutex_lock(&flowop->fo_lock);

	flowop_beginop(threadflow, flowop);
	pthread_cond_wait(&flowop->fo_cv, &flowop->fo_lock);
	flowop_endop(threadflow, flowop);

	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d unblocking", 
	    flowop->fo_name, flowop->fo_instance);

	ipc_mutex_unlock(&flowop->fo_lock);

	return(0);
}

/* wakeup */
static int
flowoplib_wakeup(threadflow_t *threadflow, flowop_t *flowop)
{
	flowop_t *target;
	flowop_t *result;
      
	/* if this is the first wakeup, create the wakeup list */
	if (flowop->fo_targets == NULL) {
		result = flowop_find(flowop->fo_targetname);
		flowop->fo_targets = result;
		if (result == NULL) {
			filebench_log(LOG_ERROR,
			    "wakeup: could not find op %s for thread %s",
			    flowop->fo_targetname,
			    threadflow->tf_name);
			filebench_shutdown(1);
		}
		while (result) {
			result->fo_targetnext =
			    result->fo_resultnext;
			result = result->fo_resultnext;
		}
	}

	target = flowop->fo_targets;

	/* wakeup the targets */
	while (target) {
		if (target->fo_instance == FLOW_MASTER) {
			target = target->fo_targetnext;
			continue;
		}
		filebench_log(LOG_DEBUG_IMPL, 
		    "wakeup flow %s-%d at address %zx",
		    target->fo_name,
		    target->fo_instance,
		    &target->fo_cv);

		flowop_beginop(threadflow, flowop);
		ipc_mutex_lock(&target->fo_lock);
 		pthread_cond_broadcast(&target->fo_cv);
		ipc_mutex_unlock(&target->fo_lock);
		flowop_endop(threadflow, flowop);

		target = target->fo_targetnext;
	}

	return(0);
}

/* hog */
static int
flowoplib_hog(threadflow_t *threadflow, flowop_t *flowop)
{
	int i;
	uint64_t value = *flowop->fo_value;

	flowop_beginop(threadflow, flowop);
	filebench_log(LOG_DEBUG_IMPL, "hog enter");
	for (i = 0; i < value; i++) {
		*(threadflow->tf_mem) = 1;
	}
	flowop_endop(threadflow, flowop);
	filebench_log(LOG_DEBUG_IMPL, "hog exit");
	return(0);
}


/* delay */
static int
flowoplib_delay(threadflow_t *threadflow, flowop_t *flowop)
{
	int value = *flowop->fo_value;

	flowop_beginop(threadflow, flowop);
	sleep(value);
	flowop_endop(threadflow, flowop);
	return(0);
}

/* eventlimit */
static int
flowoplib_eventlimit(threadflow_t *threadflow, flowop_t *flowop)
{

	/* Immediately bail if not set/enabled */
	if (filebench_shm->eventgen_hz == 0)
		return(0);

	if (flowop->fo_initted == 0) {
		filebench_log(LOG_DEBUG_IMPL, "rate %zx %s-%d locking", 
			flowop,
			threadflow->tf_name,
			threadflow->tf_instance);
		flowop->fo_initted = 1;
	}

	flowop_beginop(threadflow, flowop);
	while(filebench_shm->eventgen_hz) {
		if (filebench_shm->eventgen_q > 0) {
			filebench_shm->eventgen_q--;
			break;
		}
		ipc_mutex_lock(&filebench_shm->eventgen_lock);
		pthread_cond_wait(&filebench_shm->eventgen_cv, 
		    &filebench_shm->eventgen_lock);
		ipc_mutex_unlock(&filebench_shm->eventgen_lock);
	}
	flowop_endop(threadflow, flowop);
	return(0);
}

/* iopslimit */
static int
flowoplib_iopslimit(threadflow_t *threadflow, flowop_t *flowop)
{
	uint64_t iops;
	uint64_t delta;
	int events;

	/* Immediately bail if not set/enabled */
	if (filebench_shm->eventgen_hz == 0)
		return(0);

	if (flowop->fo_initted == 0) {
		filebench_log(LOG_DEBUG_IMPL, "rate %zx %s-%d locking", 
			flowop,
			threadflow->tf_name,
			threadflow->tf_instance);
		flowop->fo_initted = 1;
	}

	iops = (controlstats.fs_rcount + 
	    controlstats.fs_wcount);

	/* Is this the first time around */
	if (flowop->fo_tputlast == 0) {
		flowop->fo_tputlast = iops;
		return(0);
	}

	delta = iops - flowop->fo_tputlast;
	flowop->fo_tputbucket -= delta;
	flowop->fo_tputlast = iops;
	
	/* No need to block if the q isn't empty */
	if (flowop->fo_tputbucket >= 0LL) {
		flowop_endop(threadflow, flowop);
		return(0);
	}

	iops = flowop->fo_tputbucket * -1;
	events = iops;

	flowop_beginop(threadflow, flowop);
	while(filebench_shm->eventgen_hz) {

		ipc_mutex_lock(&filebench_shm->eventgen_lock);
		if (filebench_shm->eventgen_q >= events) {
			filebench_shm->eventgen_q -= events;
			ipc_mutex_unlock(&filebench_shm->eventgen_lock);
			flowop->fo_tputbucket += events;
			break;
		}
		pthread_cond_wait(&filebench_shm->eventgen_cv, 
		    &filebench_shm->eventgen_lock);
		ipc_mutex_unlock(&filebench_shm->eventgen_lock);
	}
	flowop_endop(threadflow, flowop);

	return(0);
}

/* opslimit */
static int
flowoplib_opslimit(threadflow_t *threadflow, flowop_t *flowop)
{
	uint64_t ops;
	uint64_t delta;
	int events;

	/* Immediately bail if not set/enabled */
	if (filebench_shm->eventgen_hz == 0)
		return(0);

	if (flowop->fo_initted == 0) {
		filebench_log(LOG_DEBUG_IMPL, "rate %zx %s-%d locking", 
			flowop,
			threadflow->tf_name,
			threadflow->tf_instance);
		flowop->fo_initted = 1;
	}

	ops = controlstats.fs_count;

	/* Is this the first time around */
	if (flowop->fo_tputlast == 0) {
		flowop->fo_tputlast = ops;
		return(0);
	}

	delta = ops - flowop->fo_tputlast;
	flowop->fo_tputbucket -= delta;
	flowop->fo_tputlast = ops;
	
	/* No need to block if the q isn't empty */
	if (flowop->fo_tputbucket >= 0LL) {
		flowop_endop(threadflow, flowop);
		return(0);
	}

	ops = flowop->fo_tputbucket * -1;
	events = ops;

	flowop_beginop(threadflow, flowop);
	while(filebench_shm->eventgen_hz) {
		ipc_mutex_lock(&filebench_shm->eventgen_lock);
		if (filebench_shm->eventgen_q >= events) {
			filebench_shm->eventgen_q -= events;
			ipc_mutex_unlock(&filebench_shm->eventgen_lock);
			flowop->fo_tputbucket += events;
			break;
		}
		pthread_cond_wait(&filebench_shm->eventgen_cv, 
		    &filebench_shm->eventgen_lock);
		ipc_mutex_unlock(&filebench_shm->eventgen_lock);
	}
	flowop_endop(threadflow, flowop);

	return(0);
}


/* bwlimit */
static int
flowoplib_bwlimit(threadflow_t *threadflow, flowop_t *flowop)
{
	uint64_t bytes;
	uint64_t delta;
	int events;

	/* Immediately bail if not set/enabled */
	if (filebench_shm->eventgen_hz == 0)
		return(0);

	if (flowop->fo_initted == 0) {
		filebench_log(LOG_DEBUG_IMPL, "rate %zx %s-%d locking", 
			flowop,
			threadflow->tf_name,
			threadflow->tf_instance);
		flowop->fo_initted = 1;
	}

	bytes = (controlstats.fs_rbytes + 
	    controlstats.fs_wbytes);

	/* Is this the first time around */
	if (flowop->fo_tputlast == 0) {
		flowop->fo_tputlast = bytes;
		return(0);
	}

	delta = bytes - flowop->fo_tputlast;
	flowop->fo_tputbucket -= delta;
	flowop->fo_tputlast = bytes;
	
	/* No need to block if the q isn't empty */
	if (flowop->fo_tputbucket >= 0LL) {
		flowop_endop(threadflow, flowop);
		return(0);
	}

	bytes = flowop->fo_tputbucket * -1;
	events = (bytes / MB) + 1;

	filebench_log(LOG_DEBUG_IMPL, "%lld bytes, %lld events",
	    bytes, events);

	flowop_beginop(threadflow, flowop);
	while(filebench_shm->eventgen_hz) {
		ipc_mutex_lock(&filebench_shm->eventgen_lock);
		if (filebench_shm->eventgen_q >= events) {
			filebench_shm->eventgen_q -= events;
			ipc_mutex_unlock(&filebench_shm->eventgen_lock);
			flowop->fo_tputbucket += (events * MB);
			break;
		}
		pthread_cond_wait(&filebench_shm->eventgen_cv, 
		    &filebench_shm->eventgen_lock);
		ipc_mutex_unlock(&filebench_shm->eventgen_lock);
	}
	flowop_endop(threadflow, flowop);

	return(0);
}

/* finishonbytes */
static int
flowoplib_finishonbytes(threadflow_t *threadflow, flowop_t *flowop)
{
	uint64_t b;
	uint64_t bytes = *flowop->fo_value;

	b = controlstats.fs_bytes;

	flowop_beginop(threadflow, flowop);
	if (b > bytes) {
		flowop_endop(threadflow, flowop);
		return(1);
	}
	flowop_endop(threadflow, flowop);

	return(0);
}

/* finishoncount */
static int
flowoplib_finishoncount(threadflow_t *threadflow, flowop_t *flowop)
{
	uint64_t ops;
	uint64_t count = *flowop->fo_value;

	ops = controlstats.fs_count;

	flowop_beginop(threadflow, flowop);
	if (ops > count) {
		flowop_endop(threadflow, flowop);
		return(1);
	}
	flowop_endop(threadflow, flowop);

	return(0);
}

/* sem block init */
static int 
flowoplib_semblock_init(flowop_t *flowop)
{

#ifdef HAVE_SYSV_SEM
	key_t key;
	int semid;
	struct sembuf sbuf[2];
	int highwater;

	ipc_seminit();

	flowop->fo_semid_lw = ipc_semidalloc();
	flowop->fo_semid_hw = ipc_semidalloc();

	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d semblock init semid=%x", 
	    flowop->fo_name, flowop->fo_instance, flowop->fo_semid_lw);

	/* 
	 * Raise the number of the hw queue, causing the posting side to block if
	 * queue is > 2 x blocking value
	 */
	if ((semid = semget(filebench_shm->semkey,
		  FILEBENCH_NSEMS, 0)) == -1) {
		filebench_log(LOG_ERROR, "semblock init lookup %x failed: %s",
		    filebench_shm->semkey, 
		    strerror(errno));
		return(-1);
	}

	if ((highwater = flowop->fo_semid_hw) == 0)
		highwater = *flowop->fo_value;

	filebench_log(LOG_DEBUG_IMPL, "setting highwater to : %d", highwater);

        sbuf[0].sem_num = highwater;
        sbuf[0].sem_op = *flowop->fo_highwater; 
        sbuf[0].sem_flg = 0;
	if ((semop(semid, &sbuf[0], 1) == -1) && errno) {
		filebench_log(LOG_ERROR, "semblock init post failed: %s (%d,%d)",
		    strerror(errno), sbuf[0].sem_num, sbuf[0].sem_op);
		return(-1);
	}

#else


	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d semblock init semid %llx", 
	    flowop->fo_name, flowop->fo_instance, flowop->fo_semid_lw);
#endif

	if (!(*flowop->fo_blocking))
		ipc_mutex_unlock(&flowop->fo_lock);

	return (0);
}

/* sem block destruct */
static int 
flowoplib_semblock_destruct(flowop_t *flowop)
{
	ipc_semidfree(flowop->fo_semid_lw);
	ipc_semidfree(flowop->fo_semid_hw);
	return(0);
}

/* sem block */
static int
flowoplib_semblock(threadflow_t *threadflow, flowop_t *flowop)
{
       
#ifdef HAVE_SYSV_SEM
	struct sembuf sbuf[2]; 
	int value = *flowop->fo_value;
	int semid;
	struct timespec timeout;
	int semval;


	if ((semid = semget(filebench_shm->semkey,
		  FILEBENCH_NSEMS, 0)) == -1) {
		filebench_log(LOG_ERROR, "lookup semop %x failed: %s",
		    filebench_shm->semkey, 
		    strerror(errno));
		return(-1);
	}

	filebench_log(LOG_DEBUG_IMPL, 
	    "flow %s-%d sem blocking on id %x num %x value %d", 
	    flowop->fo_name, flowop->fo_instance, semid, 
	    flowop->fo_semid_hw, value);

	/* Post, decrement the increment the hw queue */
        sbuf[0].sem_num = flowop->fo_semid_hw;
        sbuf[0].sem_op = value;
        sbuf[0].sem_flg = 0;
        sbuf[1].sem_num = flowop->fo_semid_lw;
        sbuf[1].sem_op = value * -1;
        sbuf[1].sem_flg = 0;
	timeout.tv_sec = 600;
	timeout.tv_nsec = 0;

	if (*flowop->fo_blocking)
		ipc_mutex_unlock(&flowop->fo_lock);

	flowop_beginop(threadflow, flowop);

#ifdef HAVE_SEMTIMEDOP
	semtimedop(semid, &sbuf[0], 1, &timeout);
	semtimedop(semid, &sbuf[1], 1, &timeout);
#else
	semop(semid, &sbuf[0], 1);
	semop(semid, &sbuf[1], 1);
#endif /* HAVE_SEMTIMEDOP */

	if (*flowop->fo_blocking)
		ipc_mutex_lock(&flowop->fo_lock);       

	flowop_endop(threadflow, flowop);

#else
	int value = *flowop->fo_value;
	int i;

	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d sem blocking on num %llx", 
	    flowop->fo_name, flowop->fo_instance, flowop->fo_semid_lw);

	/* Decrement sem by value */
	for (i = 0; i < value; i++) {
		if (sem_wait((sem_t *)flowop->fo_semid_lw) == -1) {
			filebench_log(LOG_ERROR, "semop wait failed");
			return(-1);
		} 
	}

	filebench_log(LOG_DEBUG_IMPL, "flow %s-%d sem unblocking", 
	    flowop->fo_name, flowop->fo_instance);
#endif /* HAVE_SYSV_SEM */

	return(0);
}

/* sem post init */
static int 
flowoplib_sempost_init(flowop_t *flowop)
{
	ipc_seminit();
}

/* sem post */
static int
flowoplib_sempost(threadflow_t *threadflow, flowop_t *flowop)
{
	int value = *flowop->fo_value;
	int i;
	flowop_t *target;
	flowop_t *result;
#ifdef HAVE_SYSV_SEM
	struct sembuf sbuf[2]; 
	int semid;
	short semnum;
	int semval;
	int blocking;
#endif /* HAVE_SYSV_SEM */
	struct timespec timeout;

	filebench_log(LOG_DEBUG_IMPL, 
	    "sempost flow %s-%d",
	    flowop->fo_name,
	    flowop->fo_instance);

	/* if this is the first post, create the post list */
	if (flowop->fo_targets == NULL) {
		result = flowop_find(flowop->fo_targetname);
		flowop->fo_targets = result;

		if (result == NULL) {
			filebench_log(LOG_ERROR,
			    "sempost: could not find op %s for thread %s",
			    flowop->fo_targetname,
			    threadflow->tf_name);
			filebench_shutdown(1);
		}

		while (result) {
			result->fo_targetnext =
			    result->fo_resultnext;
			result = result->fo_resultnext;
		}
	}

	target = flowop->fo_targets;

	flowop_beginop(threadflow, flowop);
	/* post to the targets */
	while (target) {
		if (target->fo_instance == FLOW_MASTER) {
			target = target->fo_targetnext;
			continue;
		}

		filebench_log(LOG_DEBUG_IMPL, 
		    "sempost flow %s-%d num %x",
		    target->fo_name,
		    target->fo_instance,
		    target->fo_semid_lw);

		/* ipc_mutex_lock(&target->fo_lock);*/

#ifdef HAVE_SYSV_SEM

		if ((semid = semget(filebench_shm->semkey,
			 FILEBENCH_NSEMS, 0)) == -1) {		       
			filebench_log(LOG_ERROR, 
			    "lookup semop %x failed: %s",
			    filebench_shm->semkey, 
			    strerror(errno));
			/* ipc_mutex_unlock(&target->fo_lock); */
			return(-1);
		}
		
        	sbuf[0].sem_num = target->fo_semid_lw;
        	sbuf[0].sem_op = value;
        	sbuf[0].sem_flg = 0;
        	sbuf[1].sem_num = target->fo_semid_hw;
        	sbuf[1].sem_op = value * -1;
        	sbuf[1].sem_flg = 0;
		timeout.tv_sec = 600;
		timeout.tv_nsec = 0;

		if (*flowop->fo_blocking)
			blocking = 1;
		else
			blocking = 0;

#ifdef HAVE_SEMTIMEDOP		
		if ((semtimedop(semid, &sbuf[0], blocking + 1, &timeout) == -1) &&
#else
		if ((semop(semid, &sbuf[0], blocking + 1) == -1) &&
#endif /* HAVE_SEMTIMEDOP */
		    (errno && (errno != EAGAIN))) {
			filebench_log(LOG_ERROR, "semop post failed: %s",
			    strerror(errno));
			/* ipc_mutex_unlock(&target->fo_lock);*/
			return(-1);
		} 
		
		filebench_log(LOG_DEBUG_IMPL,
		    "flow %s-%d finished posting, semval = %d", 
		    target->fo_name, target->fo_instance, semval);
#else
		/* Increment sem by value */
		for (i = 0; i < value; i++) {
			if (sem_post((sem_t *)target->fo_semid_lw) == -1) {
				filebench_log(LOG_ERROR, "semop post failed");
				/* ipc_mutex_unlock(&target->fo_lock);*/
				return(-1);
			}
		}
		
		filebench_log(LOG_DEBUG_IMPL, "flow %s-%d unblocking", 
		    target->fo_name, target->fo_instance);
#endif /* HAVE_SYSV_SEM */

		target = target->fo_targetnext;
	}
	flowop_endop(threadflow, flowop);

	return(0);
}

static int
flowoplib_openfile(threadflow_t *threadflow, flowop_t *flowop)
{
	int fd = flowoplib_fdnum(threadflow, flowop);

	if (fd == -1)
		return(-1);

	return(flowoplib_openfile_common(threadflow, flowop, fd));
}

static int
flowoplib_openfile_common(threadflow_t *threadflow, flowop_t *flowop, int fd)
{
	size_t memoffset;
	off64_t offset;
	filesetentry_t *file;
	int rsize;
	int seek;
	int ret;
	off64_t bytes = 0;
	int tid = 0;

	/* If the flowop defaults to persistent fd */
	if (integer_isset(flowop->fo_rotatefd))
		tid = threadflow->tf_utid;

	if (threadflow->tf_fd[fd] != 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s attempted to open without closing on fd %d",
		    flowop->fo_name, fd);
		return(-1);
	}

	if (flowop->fo_fileset == NULL) {
		filebench_log(LOG_ERROR, "flowop NULL file");
		return(-1);
	}

	if ((file = fileset_pick(flowop->fo_fileset,
	    FILESET_PICKEXISTS, tid)) == NULL) {
		filebench_log(LOG_ERROR,
		    "flowop %s failed to pick file from %s on fd %d",
		    flowop->fo_name,
		    flowop->fo_fileset->fs_name, fd);
		return(-1);
	}

	threadflow->tf_fse[fd] = file;
	
	flowop_beginop(threadflow, flowop);
	threadflow->tf_fd[fd] = fileset_openfile(flowop->fo_fileset,
	    file, O_RDWR, 0666, flowoplib_fileattrs(flowop));
	flowop_endop(threadflow, flowop);
	
	if (threadflow->tf_fd[fd] < 0) {
		filebench_log(LOG_ERROR, "failed to open file %s", 
		    flowop->fo_name);
		return(-1);
	}	

	filebench_log(LOG_DEBUG_SCRIPT,
	    "flowop %s: opened %s fd[%d] = %d",
	    flowop->fo_name, file->fse_path, fd, threadflow->tf_fd[fd]);

	return(0);
}

/* emulate create of a file */
static int
flowoplib_createfile(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	filesetentry_t *file;
	int rsize;
	int seek;
	int ret;
	off64_t bytes = 0;
	int fd = flowop->fo_fdnumber;

	if (threadflow->tf_fd[fd] != 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s attempted to create without closing on fd %d",
		    flowop->fo_name, fd);
		return(-1);
	}

	if (flowop->fo_fileset == NULL) {
		filebench_log(LOG_ERROR, "flowop NULL file");
		return(-1);
	}

	if ((file = fileset_pick(flowop->fo_fileset, FILESET_PICKNOEXIST, 0)) == NULL) {
		filebench_log(LOG_DEBUG_SCRIPT, "flowop %s failed to pick file",
		    flowop->fo_name);
		return(1);
	}

	threadflow->tf_fse[fd] = file;
	
	flowop_beginop(threadflow, flowop);
	threadflow->tf_fd[fd] = fileset_openfile(flowop->fo_fileset,
	    file, O_RDWR | O_CREAT, 0666, flowoplib_fileattrs(flowop));
	flowop_endop(threadflow, flowop);
	
	if (threadflow->tf_fd[fd] < 0) {
		filebench_log(LOG_ERROR, "failed to create file %s", 
		    flowop->fo_name);
		return(-1);
	}	

	filebench_log(LOG_DEBUG_SCRIPT,
	    "flowop %s: created %s fd[%d] = %d",
	    flowop->fo_name, file->fse_path, fd, threadflow->tf_fd[fd]);

	return(0);
}

/* emulate delete of a file */
static int
flowoplib_deletefile(threadflow_t *threadflow, flowop_t *flowop)
{
	filesetentry_t *file;
	fileset_t *fileset;
	char path[MAXPATHLEN];
	char *pathtmp;
	struct stat sb;
	int fd;


	if (flowop->fo_fileset == NULL) {
		filebench_log(LOG_ERROR, "flowop NULL file");
		return(-1);
	}

	fileset = flowop->fo_fileset;
	
	if ((file = fileset_pick(flowop->fo_fileset, FILESET_PICKEXISTS, 0)) == NULL) {
		filebench_log(LOG_DEBUG_SCRIPT, "flowop %s failed to pick file",
		    flowop->fo_name);
		return(1);
	}

	*path = 0;
	strcpy(path, *fileset->fs_path);
	strcat(path, "/");
	strcat(path, fileset->fs_name);
	pathtmp = fileset_resolvepath(file);
	strcat(path, pathtmp);
	free(pathtmp);

	flowop_beginop(threadflow, flowop);
	unlink(path);
	flowop_endop(threadflow, flowop);
	file->fse_flags &= ~FSE_EXISTS;
	ipc_mutex_unlock(&file->fse_lock);

	filebench_log(LOG_DEBUG_SCRIPT, "deleted file %s", file->fse_path);

	return(0);
}

/* emulate fsync of a file */
static int
flowoplib_fsync(threadflow_t *threadflow, flowop_t *flowop)
{
	filesetentry_t *file;
	int fd = flowop->fo_fdnumber;

	if (threadflow->tf_fd[fd] == 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s attempted to fsync a closed fd %d",
		    flowop->fo_name, fd);
		return(-1);
	}

	/* Measure time to fsync */
	flowop_beginop(threadflow, flowop);
	fsync(threadflow->tf_fd[fd]);
	flowop_endop(threadflow, flowop);

	file = threadflow->tf_fse[fd];

	filebench_log(LOG_DEBUG_SCRIPT, "fsync file %s", file->fse_path);

	return(0);
}

/* emulate fsync of an entire fileset */
static int
flowoplib_fsyncset(threadflow_t *threadflow, flowop_t *flowop)
{
	filesetentry_t *file;
	int fd;

	for (fd = 0; fd < THREADFLOW_MAXFD; fd++) {

		/* Match the file set to fsync */
		if ((threadflow->tf_fse[fd] == NULL) ||
		    (flowop->fo_fileset != threadflow->tf_fse[fd]->fse_fileset)) 
			continue;

		/* Measure time to fsync */
		flowop_beginop(threadflow, flowop);
		fsync(threadflow->tf_fd[fd]);
		flowop_endop(threadflow, flowop);
	
		file = threadflow->tf_fse[fd];

		filebench_log(LOG_DEBUG_SCRIPT, "fsync file %s", file->fse_path);
	}

	return(0);
}

/* emulate close of a file */
static int
flowoplib_closefile(threadflow_t *threadflow, flowop_t *flowop)
{
	filesetentry_t *file;
	int fd = flowop->fo_fdnumber;

	if (threadflow->tf_fd[fd] == 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s attempted to close an already closed fd %d",
		    flowop->fo_name, fd);
		return(-1);
	}

	/* Measure time to close */
	flowop_beginop(threadflow, flowop);
	close(threadflow->tf_fd[fd]);
	flowop_endop(threadflow, flowop);

	file = threadflow->tf_fse[fd];

	threadflow->tf_fd[fd] = 0;
	threadflow->tf_fse[fd] = NULL;

	filebench_log(LOG_DEBUG_SCRIPT, "closed file %s", file->fse_path);

	return(0);
}

/* emulate stat of a file */
static int
flowoplib_statfile(threadflow_t *threadflow, flowop_t *flowop)
{
	filesetentry_t *file;
	fileset_t *fileset;
	char path[MAXPATHLEN];
	char *pathtmp;
	struct stat sb;
	int fd;


	if (flowop->fo_fileset == NULL) {
		filebench_log(LOG_ERROR, "flowop NULL file");
		return(-1);
	}

	fileset = flowop->fo_fileset;
	
	if ((file = fileset_pick(flowop->fo_fileset, FILESET_PICKEXISTS, 0)) == NULL) {
		filebench_log(LOG_DEBUG_SCRIPT, "flowop %s failed to pick file",
		    flowop->fo_name);
		return(1);
	}

	*path = 0;
	strcpy(path, *fileset->fs_path);
	strcat(path, "/");
	strcat(path, fileset->fs_name);
	pathtmp = fileset_resolvepath(file);
	strcat(path, pathtmp);
	free(pathtmp);

	flowop_beginop(threadflow, flowop);
	stat(path, &sb);
	flowop_endop(threadflow, flowop);

	ipc_mutex_unlock(&file->fse_lock);

	return(0);
}

/* emulate read of a whole file */
static int
flowoplib_readwholefile(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	filesetentry_t *file;
	int rsize;
	long memsize, round;
	int seek;
	int ret;
	off64_t bytes = 0;
	int fd = flowop->fo_fdnumber;

	if (threadflow->tf_fd[fd] == 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s attempted to read a closed fd %d",
		    flowop->fo_name, fd);
		return(-1);
	}

	if ((flowop->fo_buf == NULL) &&
	    ((flowop->fo_buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL)) {
		return(-1);
	}

	if ((file = threadflow->tf_fse[fd]) == NULL) {
		filebench_log(LOG_ERROR, "flowop %s: NULL file", 
			flowop->fo_name);
		return(-1);
	}
	
	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);
	
	/* Measure time to read bytes */
	flowop_beginop(threadflow, flowop);
	lseek64(threadflow->tf_fd[fd], 0, SEEK_SET);
	while ((ret = read(threadflow->tf_fd[fd], flowop->fo_buf, 
		    FILE_ALLOC_BLOCK)) > 0)
		bytes += ret;

	flowop_endop(threadflow, flowop);

	if (ret < 0) {
		filebench_log(LOG_ERROR,
		    "Failed to read fd %d: %s",
		    fd, strerror(errno));
		return(-1);
	}

	if (flowop->fo_iosize == NULL)
		flowop->fo_iosize = integer_alloc(bytes);
	*(flowop->fo_iosize) = bytes;

	return(0);
}

/* emulate write of a whole file */
static int
flowoplib_write(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	vinteger_t wss;
	off64_t offset;
	filesetentry_t *file;
	int wsize;
	int seek;
	int ret;
	off64_t bytes = 0;
	long memsize, round;
	int fd;
	int filedesc;

	if (flowop->fo_fileset || flowop->fo_fdnumber) {
		fd = flowoplib_fdnum(threadflow, flowop);

		if (fd == -1)
			return(-1);

		if (threadflow->tf_fd[fd] == 0) {
			flowoplib_openfile_common(threadflow, flowop, fd);
			filebench_log(LOG_DEBUG_IMPL, "read opened file %s",
			    threadflow->tf_fse[fd]->fse_path);
		}
		filedesc = threadflow->tf_fd[fd];
		if (*flowop->fo_wss == 0)
			wss = threadflow->tf_fse[fd]->fse_size;
		else
			wss = *flowop->fo_wss;
	} else {
		if (flowop->fo_file == NULL) {
			filebench_log(LOG_ERROR, "flowop NULL file");
			return(-1);
		}	
		if (flowop->fo_fd < 0)
			flowop->fo_fd = fileobj_open(flowop->fo_file,
			    flowoplib_fileattrs(flowop));
		
		if (flowop->fo_fd < 0) {
			filebench_log(LOG_ERROR, "failed to open file %s", 
			    flowop->fo_file->fo_name);
			return(-1);
		}
		filedesc = flowop->fo_fd;
		if (*flowop->fo_wss == 0)
			wss = *flowop->fo_file->fo_size;
		else
			wss = *flowop->fo_wss;
	}

	if ((flowop->fo_buf == NULL) &&
	    ((flowop->fo_buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL)) {
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);
	
	if (*flowop->fo_wss == 0)
		wss = file->fse_size;
	else
		wss = *flowop->fo_wss;

	if (*flowop->fo_iosize == 0) {
		filebench_log(LOG_ERROR, "zero iosize for thread %s", 
		    flowop->fo_name);
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);

	if (*flowop->fo_random) {
		offset = filebench_randomno64(wss , *flowop->fo_iosize);
		flowop_beginop(threadflow, flowop);
		if ((bytes = pwrite64(filedesc,
		    threadflow->tf_mem + memoffset, 
		    *flowop->fo_iosize, offset) == -1)) {
			filebench_log(LOG_ERROR, 
			    "write file %s failed, offset %lld memoffset %zd: %s",
			    file->fse_path,
			    offset, memoffset, strerror(errno));
			flowop_endop(threadflow, flowop);
			return(-1);
		}
		flowop_endop(threadflow, flowop);
	} else {
		flowop_beginop(threadflow, flowop);
		if ((bytes = write(filedesc,
		    threadflow->tf_mem + memoffset, 
		    *flowop->fo_iosize) == -1)) {
			filebench_log(LOG_ERROR, 
			    "write file %s failed, memoffset %zd: %s",
			    file->fse_path,
			    memoffset, strerror(errno));
			flowop_endop(threadflow, flowop);
			return(-1);
		}
		flowop_endop(threadflow, flowop);
	}

	return(0);
}

/* emulate write of a whole file */
static int
flowoplib_writewholefile(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	filesetentry_t *file;
	int wsize;
	int seek;
	int ret;
	off64_t bytes = 0;
	long memsize, round;
	int fd = flowop->fo_fdnumber;
	int srcfd = flowop->fo_srcfdnumber;
	vinteger_t wss;

	if (threadflow->tf_fd[fd] == 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s attempted to write a closed fd %d",
		    flowop->fo_name, fd);
		return(-1);
	}

	if ((flowop->fo_buf == NULL) &&
	    ((flowop->fo_buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL)) {
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);
	
	file = threadflow->tf_fse[srcfd];
	if (((srcfd != 0) && (file == NULL)) ||
	    ((file = threadflow->tf_fse[fd]) == NULL)) {
		filebench_log(LOG_ERROR, "flowop %s: NULL file", 
			flowop->fo_name);
		return(-1);
	}

	wsize = MIN(file->fse_size, FILE_ALLOC_BLOCK);
	
	/* Measure time to write bytes */
	flowop_beginop(threadflow, flowop);
	for (seek = 0; seek < file->fse_size;
	     seek += FILE_ALLOC_BLOCK) {
		ret = write(threadflow->tf_fd[fd], flowop->fo_buf, wsize);
		if (ret != wsize) {
			filebench_log(LOG_ERROR,
			    "Failed to write %d bytes on fd %d: %s",
			    threadflow->tf_fd[fd], fd, strerror(errno));
			flowop_endop(threadflow, flowop);
			return(-1);
		}
		bytes += ret;
	}
	flowop_endop(threadflow, flowop);

	if (flowop->fo_iosize == NULL)
		flowop->fo_iosize = integer_alloc(bytes);
	*(flowop->fo_iosize) = bytes;

	return(0);
}


/* emulate fixed sized append to a file */
static int
flowoplib_appendfile(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	off64_t wsize;
	off64_t seek;
	int ret;
	off64_t bytes = 0;
	int iosize;
	long memsize, round;
	int fd;
	int filedesc;
	vinteger_t wss;

	if (flowop->fo_fileset || flowop->fo_fdnumber) {
		fd = flowoplib_fdnum(threadflow, flowop);

		if (fd == -1)
			return(-1);

		if (threadflow->tf_fd[fd] == 0) {
			flowoplib_openfile_common(threadflow, flowop, fd);
			filebench_log(LOG_DEBUG_IMPL, "read opened file %s",
			    threadflow->tf_fse[fd]->fse_path);
		}
		filedesc = threadflow->tf_fd[fd];
		if (*flowop->fo_wss == 0)
			wss = threadflow->tf_fse[fd]->fse_size;
		else
			wss = *flowop->fo_wss;
	} else {
		if (flowop->fo_file == NULL) {
			filebench_log(LOG_ERROR, "flowop NULL file");
			return(-1);
		}	
		if (flowop->fo_fd < 0)
			flowop->fo_fd = fileobj_open(flowop->fo_file,
			    flowoplib_fileattrs(flowop));
		
		if (flowop->fo_fd < 0) {
			filebench_log(LOG_ERROR, "failed to open file %s", 
			    flowop->fo_file->fo_name);
			return(-1);
		}
		filedesc = flowop->fo_fd;
		if (*flowop->fo_wss == 0)
			wss = *flowop->fo_file->fo_size;
		else
			wss = *flowop->fo_wss;
	}

	if ((flowop->fo_buf == NULL) &&
	    ((flowop->fo_buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL)) {
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	wsize = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, wsize);
	
	/* Measure time to write bytes */
	flowop_beginop(threadflow, flowop);
	lseek64(filedesc, 0, SEEK_END);
	ret = write(filedesc, flowop->fo_buf, wsize);
	if (ret != wsize) {
		filebench_log(LOG_ERROR,
		    "Failed to write %d bytes on fd %d: %s",
		    wsize, fd, strerror(errno));
		flowop_endop(threadflow, flowop);
		return(-1);
	}
	flowop_endop(threadflow, flowop);

	return(0);
}

/* emulate random sized append to a file */
static int
flowoplib_appendfilerand(threadflow_t *threadflow, flowop_t *flowop)
{
	size_t memoffset;
	off64_t offset;
	off64_t wsize;
	off64_t appendsize;
	off64_t seek;
	int ret;
	off64_t bytes = 0;
	int iosize;
	long memsize, round;
	int fd;
	int filedesc;
	vinteger_t wss;

	if (flowop->fo_fileset || flowop->fo_fdnumber) {
		fd = flowoplib_fdnum(threadflow, flowop);

		if (fd == -1)
			return(-1);

		if (threadflow->tf_fd[fd] == 0) {
			flowoplib_openfile_common(threadflow, flowop, fd);
			filebench_log(LOG_DEBUG_IMPL, "append opened file %s",
			    threadflow->tf_fse[fd]->fse_path);
		}
		filedesc = threadflow->tf_fd[fd];
		if (*flowop->fo_wss == 0)
			wss = threadflow->tf_fse[fd]->fse_size;
		else
			wss = *flowop->fo_wss;
	} else {
		if (flowop->fo_file == NULL) {
			filebench_log(LOG_ERROR, "flowop NULL file");
			return(-1);
		}	
		if (flowop->fo_fd < 0)
			flowop->fo_fd = fileobj_open(flowop->fo_file,
			    flowoplib_fileattrs(flowop));
		
		if (flowop->fo_fd < 0) {
			filebench_log(LOG_ERROR, "failed to open file %s", 
			    flowop->fo_file->fo_name);
			return(-1);
		}
		filedesc = flowop->fo_fd;
		if (*flowop->fo_wss == 0)
			wss = *flowop->fo_file->fo_size;
		else
			wss = *flowop->fo_wss;
	}

	if ((flowop->fo_buf == NULL) &&
	    ((flowop->fo_buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL)) {
		return(-1);
	}

	memsize = *threadflow->tf_memsize;
	round = *flowop->fo_iosize;
	memoffset = filebench_randomno(memsize, round);
	appendsize = filebench_randomno64(*flowop->fo_iosize, 1LL);

	/* Measure time to write bytes */
	flowop_beginop(threadflow, flowop);
	for (seek = 0; seek < appendsize;
	     seek += FILE_ALLOC_BLOCK) {
		lseek64(filedesc, 0, SEEK_END);
		wsize = ((appendsize - seek) > FILE_ALLOC_BLOCK) ?
		    FILE_ALLOC_BLOCK : (appendsize - seek);
		ret = write(filedesc, flowop->fo_buf, wsize);
		if (ret != wsize) {
			filebench_log(LOG_ERROR,
			    "Failed to write %d bytes on fd %d: %s",
			    wsize, fd, strerror(errno));
			flowop_endop(threadflow, flowop);
			return(-1);
		}
		bytes += ret;
	}
	flowop_endop(threadflow, flowop);

	return(0);
}


void
flowoplib_usage()
{
	fprintf(stderr, "flowop [openfile|createfile] name=<name>,fileset=<fname>\n");
	fprintf(stderr, "                       [,fd=<file desc num>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop closefile name=<name>,fd=<file desc num>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop deletefile name=<name>\n");
	fprintf(stderr, "                       [,fileset=<fname>]\n");
	fprintf(stderr, "                       [,fd=<file desc num>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop statfile name=<name>\n");
	fprintf(stderr, "                       [,fileset=<fname>]\n");
	fprintf(stderr, "                       [,fd=<file desc num>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop fsync name=<name>,fd=<file desc num>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop fsyncset name=<name>,fileset=<fname>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop [write|read|aiowrite] name=<name>, \n");
	fprintf(stderr, "                       filename|fileset=<fname>,\n");
	fprintf(stderr, "                       iosize=<size>\n");
	fprintf(stderr, "                       [,directio]\n");
	fprintf(stderr, "                       [,dsync]\n");
	fprintf(stderr, "                       [,iters=<count>]\n");
	fprintf(stderr, "                       [,random]\n");
	fprintf(stderr, "                       [,opennext]\n");
	fprintf(stderr, "                       [,workingset=<size>]\n");
	fprintf(stderr, "flowop [appendfile|appendfilerand] name=<name>, \n");
	fprintf(stderr, "                       filename|fileset=<fname>,\n");
	fprintf(stderr, "                       iosize=<size>\n");
	fprintf(stderr, "                       [,dsync]\n");
	fprintf(stderr, "                       [,iters=<count>]\n");
	fprintf(stderr, "                       [,workingset=<size>]\n");
	fprintf(stderr, "flowop [readwholefile|writewholefile] name=<name>, \n");
	fprintf(stderr, "                       filename|fileset=<fname>,\n");
	fprintf(stderr, "                       iosize=<size>\n");
	fprintf(stderr, "                       [,dsync]\n");
	fprintf(stderr, "                       [,iters=<count>]\n");
	fprintf(stderr, "\n"); 
	fprintf(stderr, "flowop aiowait name=<name>,target=<aiowrite-flowop>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "flowop sempost name=<name>,target=<semblock-flowop>,\n");
	fprintf(stderr, "                       value=<increment-to-post>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "flowop semblock name=<name>,value=<decrement-to-receive>,\n");
	fprintf(stderr, "                       highwater=<inbound-queue-max>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "flowop block name=<name>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "flowop wakeup name=<name>,target=<block-flowop>,\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "flowop hog name=<name>,value=<number-of-mem-ops>\n");
	fprintf(stderr, "flowop delay name=<name>,value=<number-of-seconds>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "flowop eventlimit name=<name>\n");
	fprintf(stderr, "flowop bwlimit name=<name>,value=<mb/s>\n");
	fprintf(stderr, "flowop iopslimit name=<name>,value=<iop/s>\n");
	fprintf(stderr, "flowop finishoncount name=<name>,value=<ops/s>\n");
	fprintf(stderr, "flowop finishonbytes name=<name>,value=<bytes>\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "\n");
}

