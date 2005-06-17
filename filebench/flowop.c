/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>

#ifdef HAVE_LWPS
#include <sys/lwp.h>
#endif
#include <fcntl.h>
#include "filebench.h"
#include "flowop.h"
#include "stats.h"

#ifdef LINUX_PORT
#include <sys/types.h>
#include <linux/unistd.h>
_syscall0(pid_t,gettid)
#endif

static flowop_t * flowop_define_common(threadflow_t *threadflow, char *name, 
	flowop_t *inherit, int instance, int type);

int
flowop_printlist(flowop_t *list)
{
	flowop_t *flowop = list;

	while(flowop) {
		filebench_log(LOG_DEBUG_IMPL, "flowop-list %s-%d",
		    flowop->fo_name, flowop->fo_instance);
		flowop = flowop->fo_threadnext;
	}
	return (0);
}

#define TIMESPEC_TO_HRTIME(s, e) (((e.tv_sec - s.tv_sec) * 1000000000LL) + \
                                 (e.tv_nsec - s.tv_nsec))
void
flowop_beginop(threadflow_t *threadflow, flowop_t *flowop)
{
#ifdef HAVE_PROCFS
	char procname[128];

	if ((noproc == 0) && (threadflow->tf_lwpusagefd == 0)) {
		sprintf(procname, "/proc/%d/lwp/%d/lwpusage", 
		    pid, _lwp_self());
		threadflow->tf_lwpusagefd = open(procname, O_RDONLY);
	}

	pread(threadflow->tf_lwpusagefd,
	    &threadflow->tf_susage,
	    sizeof(struct prusage), 0);

	/* Compute overhead time in this thread around op */
	if (threadflow->tf_eusage.pr_stime.tv_nsec) {
		flowop->fo_stats.fs_mstate[FLOW_MSTATE_OHEAD] += 
		    TIMESPEC_TO_HRTIME(threadflow->tf_eusage.pr_utime,
			threadflow->tf_susage.pr_utime) +
		    TIMESPEC_TO_HRTIME(threadflow->tf_eusage.pr_ttime,
			threadflow->tf_susage.pr_ttime) +
		    TIMESPEC_TO_HRTIME(threadflow->tf_eusage.pr_stime,
			threadflow->tf_susage.pr_stime);
	}
#endif
	/* Start of op for this thread */
	threadflow->tf_stime = gethrtime();
}

flowstat_t controlstats;
int controlstats_zeroed = 0;

void
flowop_endop(threadflow_t *threadflow, flowop_t *flowop)
{
	int r;
	hrtime_t t;

	flowop->fo_stats.fs_mstate[FLOW_MSTATE_LAT] += 
		    (gethrtime() - threadflow->tf_stime);

#ifdef HAVE_PROCFS
	if ((r = pread(threadflow->tf_lwpusagefd,
	    &threadflow->tf_eusage,
	    sizeof(struct prusage), 0)) != sizeof(struct prusage))
		filebench_log(LOG_ERROR, "cannot read /proc");
	
	t =
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_utime,
		threadflow->tf_eusage.pr_utime) +
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_ttime,
		threadflow->tf_eusage.pr_ttime) +
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_stime,
		threadflow->tf_eusage.pr_stime);
	flowop->fo_stats.fs_mstate[FLOW_MSTATE_CPU] += t;

	flowop->fo_stats.fs_mstate[FLOW_MSTATE_WAIT] += 
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_tftime,
		threadflow->tf_eusage.pr_tftime) +
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_dftime,
		threadflow->tf_eusage.pr_dftime) +
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_kftime,
		threadflow->tf_eusage.pr_kftime) +
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_kftime,
		threadflow->tf_eusage.pr_kftime) +
	    TIMESPEC_TO_HRTIME(threadflow->tf_susage.pr_slptime,
		threadflow->tf_eusage.pr_slptime);
#endif

 	flowop->fo_stats.fs_count++;
	flowop->fo_stats.fs_bytes += *flowop->fo_iosize;
	if ((flowop->fo_type & FLOW_TYPE_IO) ||
	    (flowop->fo_type & FLOW_TYPE_AIO)) {
		controlstats.fs_count++;
		controlstats.fs_bytes += *flowop->fo_iosize;
	}
	if (flowop->fo_attrs & FLOW_ATTR_READ) {
		threadflow->tf_stats.fs_rbytes += *flowop->fo_iosize;
		threadflow->tf_stats.fs_rcount++;
		flowop->fo_stats.fs_rcount++;
		controlstats.fs_rbytes += *flowop->fo_iosize;
		controlstats.fs_rcount++;
	} else if (flowop->fo_attrs & FLOW_ATTR_WRITE) {
		threadflow->tf_stats.fs_wbytes+= *flowop->fo_iosize;
		threadflow->tf_stats.fs_wcount++;
		flowop->fo_stats.fs_wcount++;
		controlstats.fs_wbytes += *flowop->fo_iosize;
		controlstats.fs_wcount++;
	}
}

void
flowop_start(threadflow_t *threadflow) 
{
	flowop_t *flowop;
	flowop_t *newflowop;
	int i;
	hrtime_t start;
	int rtn;
	int r;
	char procname[128];
#ifdef HAVE_PROCFS
	int pfd;
 	long ctl[2] = {PCSET, PR_MSACCT};
#endif

	pid = getpid();

#ifdef HAVE_PROCFS
	if (noproc == 0) {
		sprintf(procname, "/proc/%d/lwp/%d/lwpctl", 
		    pid, _lwp_self());
		pfd = open(procname, O_WRONLY);
		pwrite(pfd, &ctl, sizeof(ctl), 0);
		close(pfd);
	}
#endif

	if (!controlstats_zeroed) {
		memset(&controlstats, 0, sizeof(controlstats));
		controlstats_zeroed = 1;
	}

	flowop = threadflow->tf_ops;
	threadflow->tf_stats.fs_stime = gethrtime();
	flowop->fo_stats.fs_stime = gethrtime();

	/* Hold the run lock as reader to prevent lookups */
	pthread_rwlock_rdlock(&filebench_shm->flowop_find_lock);

	/* Block until all processes have started */
	pthread_rwlock_wrlock(&filebench_shm->run_lock);
	pthread_rwlock_unlock(&filebench_shm->run_lock);

	/* Create the runtime flowops from those defined by the script */
	ipc_mutex_lock(&filebench_shm->flowop_lock);
	while (flowop) {
		if (flowop == threadflow->tf_ops)
			threadflow->tf_ops = NULL;
		newflowop = flowop_define_common(threadflow, flowop->fo_name,
		    flowop, 1, 0);
		if (newflowop == NULL)
			return;
		if (flowop_initflow(newflowop) < 0)
			filebench_log(LOG_ERROR, "Flowop init of %s failed",
				newflowop->fo_name);
		flowop = flowop->fo_threadnext;
	}
	ipc_mutex_unlock(&filebench_shm->flowop_lock);

	/* Release the run lock as reader to allow lookups */
	pthread_rwlock_unlock(&filebench_shm->flowop_find_lock);

	/* Set to the start of the new flowop list */
	flowop = threadflow->tf_ops;

	threadflow->tf_abort = 0;
	threadflow->tf_running = 1;

	/* If we are going to use ISM, allocate later */
	if (threadflow->tf_attrs & THREADFLOW_USEISM) {
		threadflow->tf_mem =
		    ipc_ismmalloc((size_t)*threadflow->tf_memsize);
	} else {
		threadflow->tf_mem = malloc((size_t)*threadflow->tf_memsize);
	}

	(void) memset(threadflow->tf_mem, 0, 
	    *threadflow->tf_memsize);

#ifdef HAVE_LWPS       
	filebench_log(LOG_DEBUG_SCRIPT, "Thread %zx (%d) started",
	    threadflow,
	    _lwp_self());
#endif

	/* Main filebench worker loop */
	while (1) {

		/* Abort if asked */
		if (threadflow->tf_abort || filebench_shm->f_abort) {
			ipc_mutex_lock(&threadflow->tf_lock);
			threadflow->tf_running = 0;
			ipc_mutex_unlock(&threadflow->tf_lock);
			break;
		}

		/* Be quiet while stats are gathered */
		if (filebench_shm->bequiet) {
			sleep(1);
			continue;
		}

		/* Take it easy until everyone is ready to go */
		if (!filebench_shm->allrunning) {
			sleep(1);
		}

		if (flowop->fo_stats.fs_stime == 0)
			flowop->fo_stats.fs_stime = gethrtime();

		if (flowop == NULL) {
			filebench_log(LOG_ERROR, "flowop_read null flowop");
			return;
		}		
		
		if (threadflow->tf_memsize == 0) {
			filebench_log(LOG_ERROR,
			    "Zero memory size for thread %s", 
			    threadflow->tf_name);
			return;
		}

		filebench_log(LOG_DEBUG_SCRIPT, "%s: executing flowop %s-%d",
		    threadflow->tf_name, flowop->fo_name, flowop->fo_instance);

		for (i = 0; i < *flowop->fo_iters; i++) {
			rtn = (*flowop->fo_func)(threadflow, flowop);
			if (rtn > 0) {
				filebench_log(LOG_VERBOSE,
				    "%s: exiting flowop %s-%d",
				    threadflow->tf_name, flowop->fo_name, 
				    flowop->fo_instance);
				ipc_mutex_lock(&threadflow->tf_lock);
				threadflow->tf_abort = 1;
				filebench_shm->f_abort = 1;
				threadflow->tf_running = 0;
				ipc_mutex_unlock(&threadflow->tf_lock);
				break;
			}
			if (rtn < 0) {
				filebench_log(LOG_ERROR, "flowop %s failed", 
				    flowop->fo_name);
				ipc_mutex_lock(&threadflow->tf_lock);
				threadflow->tf_abort = 1;
				filebench_shm->f_abort = 1;
				threadflow->tf_running = 0;
				ipc_mutex_unlock(&threadflow->tf_lock);
				break;
			}
		}

		flowop = flowop->fo_threadnext;

		if (flowop == NULL) {
			flowop = threadflow->tf_ops;
		        threadflow->tf_stats.fs_count++;
		}
	}

#ifdef HAVE_LWPS
	filebench_log(LOG_DEBUG_SCRIPT, "Thread %d exiting", 
	    _lwp_self());
#endif

	pthread_exit(&rtn);
}

int
flowop_init()
{
	return flowoplib_init();
}

int
flowop_delete(flowop_t **flowoplist, flowop_t *flowop)
{
	flowop_t *entry = *flowoplist;
	int found = 0;

	filebench_log(LOG_DEBUG_IMPL, "Deleting flowop (%s-%d)",
	    flowop->fo_name,
	    flowop->fo_instance);

	/* Delete from thread's flowop list */
	if (flowop == *flowoplist) {
		/* First on list */
		*flowoplist = flowop->fo_threadnext;
		filebench_log(LOG_DEBUG_IMPL,
		    "Delete0 flowop: (%s-%d)",
		    flowop->fo_name,
		    flowop->fo_instance);
	} else {

		while (entry->fo_threadnext) {
			filebench_log(LOG_DEBUG_IMPL,
			    "Delete0 flowop: (%s-%d) == (%s-%d)",
			    entry->fo_threadnext->fo_name,
			    entry->fo_threadnext->fo_instance,
			    flowop->fo_name,
			    flowop->fo_instance);
			
			if (flowop == entry->fo_threadnext) {
				/* Delete */
				filebench_log(LOG_DEBUG_IMPL,
				    "Deleted0 flowop: (%s-%d)",
				    entry->fo_threadnext->fo_name,
				    entry->fo_threadnext->fo_instance);
				entry->fo_threadnext = entry->fo_threadnext->fo_threadnext;
				break;
			}
			entry = entry->fo_threadnext;
		}
	}

	/* Call destructor */
	flowop_destructflow(flowop);

	/* Close /proc stats */
	if (flowop->fo_thread)
		close(flowop->fo_thread->tf_lwpusagefd);

	/* Delete from global list */
	entry = filebench_shm->flowoplist;

	if (flowop == filebench_shm->flowoplist) {
		/* First on list */
		filebench_shm->flowoplist = flowop->fo_next;
		found = 1;
	} else {

		while (entry->fo_next) {
			filebench_log(LOG_DEBUG_IMPL,
			    "Delete flowop: (%s-%d) == (%s-%d)",
			    entry->fo_next->fo_name,
			    entry->fo_next->fo_instance,
			    flowop->fo_name,
			    flowop->fo_instance);
		
			if (flowop == entry->fo_next) {
				/* Delete */
				entry->fo_next = entry->fo_next->fo_next;
				found = 1;
				break;
			}
			
			entry = entry->fo_next;
		}
	}
	if (found) {
		filebench_log(LOG_DEBUG_IMPL,
		    "Deleted flowop: (%s-%d)",
		    flowop->fo_name,
		    flowop->fo_instance);
		ipc_free(FILEBENCH_FLOWOP, (char *)flowop);
	} else
		filebench_log(LOG_DEBUG_IMPL, "Flowop %s-%d not found!",
		    flowop->fo_name,
		    flowop->fo_instance);

	return(0);
}

int
flowop_delete_all(flowop_t **flowoplist)
{
	flowop_t *flowop = *flowoplist;

	filebench_log(LOG_DEBUG_IMPL, "Deleting all flowops...");
	while (flowop) {
		filebench_log(LOG_DEBUG_IMPL, "Deleting all flowops (%s-%d)",
			flowop->fo_name, flowop->fo_instance);
		flowop = flowop->fo_threadnext;
	}

	flowop = *flowoplist;

	ipc_mutex_lock(&filebench_shm->flowop_lock);	

	while (flowop) {
		if (flowop->fo_instance && 
			(flowop->fo_instance == FLOW_MASTER)) {
			flowop = flowop->fo_threadnext;
			continue;
		}
		flowop_delete(flowoplist, flowop);
		flowop = flowop->fo_threadnext;
	}

	ipc_mutex_unlock(&filebench_shm->flowop_lock);	
	
}

static flowop_t *
flowop_define_common(threadflow_t *threadflow, char *name, flowop_t *inherit,
    int instance, int type)
{
	flowop_t *flowop;
	flowop_t *flowend;

	if (name == NULL)
		return NULL;

	flowop = (flowop_t *)ipc_malloc(FILEBENCH_FLOWOP);

	filebench_log(LOG_DEBUG_IMPL, "defining flowops %s-%d, addr %zx",
	    name, instance, flowop);

	if (flowop == NULL)
		return (NULL);

	if (inherit) {
		memcpy(flowop, inherit, sizeof(flowop_t));
		pthread_mutex_init(&flowop->fo_lock, ipc_mutexattr());
		ipc_mutex_lock(&flowop->fo_lock);		
		flowop->fo_next = NULL;
		flowop->fo_threadnext = NULL;
		flowop->fo_fd = -1;
		filebench_log(LOG_DEBUG_IMPL, 
		    "flowop %s-%d calling init", name, instance);
	} else {
		memset(flowop, 0, sizeof(flowop_t));
		flowop->fo_fd = -1;
		flowop->fo_iters = integer_alloc(1);
		flowop->fo_type = type;
		pthread_mutex_init(&flowop->fo_lock, ipc_mutexattr());
		ipc_mutex_lock(&flowop->fo_lock);		
	}

	/* Create backpointer to thread */
	flowop->fo_thread = threadflow;

	/* Add flowop to global list */
	if (filebench_shm->flowoplist == NULL) {
		filebench_shm->flowoplist = flowop;
		flowop->fo_next = NULL;
	} else {
		flowop->fo_next = filebench_shm->flowoplist;
		filebench_shm->flowoplist = flowop;
	}

	strcpy(flowop->fo_name, name);
	flowop->fo_instance = instance;

	if (threadflow == NULL)
		return(flowop);

	/* Add flowop to thread op list */
	if (threadflow->tf_ops == NULL) {
		threadflow->tf_ops = flowop;
		flowop->fo_threadnext = NULL;
	} else {
		/* Find the end of the thread list */
		flowend = threadflow->tf_ops;
		while(flowend->fo_threadnext != NULL)
			flowend = flowend->fo_threadnext;
		flowend->fo_threadnext = flowop;
		flowop->fo_threadnext = NULL;
	}

	return(flowop);
}

flowop_t *
flowop_define(threadflow_t *threadflow, char *name, flowop_t *inherit,
    int instance, int type)
{
	flowop_t *flowop;

	ipc_mutex_lock(&filebench_shm->flowop_lock);
	flowop = flowop_define_common(threadflow, name,
	    inherit, instance, type);
	ipc_mutex_unlock(&filebench_shm->flowop_lock);

	if (flowop == NULL)
		return(NULL);
	
	ipc_mutex_unlock(&flowop->fo_lock);

	return(flowop);
}

int
flowop_initflow(flowop_t *flowop)
{
	if ((*flowop->fo_init)(flowop) < 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s-%d init failed", 
			flowop->fo_name, flowop->fo_instance);
		return(-1);
	}
	return(0);
}

int
flowop_destructflow(flowop_t *flowop)
{
	if ((*flowop->fo_destruct)(flowop) < 0) {
		filebench_log(LOG_ERROR,
		    "flowop %s-%d destructor failed", 
			flowop->fo_name, flowop->fo_instance);
		return(-1);
	}
	return(0);
}

/* Return a list of results */
flowop_t *
flowop_find(char *name)
{
	flowop_t *flowop = filebench_shm->flowoplist;
	flowop_t *result = NULL;

	flowop_find_barrier();

	ipc_mutex_lock(&filebench_shm->flowop_lock);

	while (flowop) {


#ifdef NEVER
		filebench_log(LOG_DEBUG_SCRIPT,
		    "Find: (%s) == (%s-%d)",
		    name,
		    flowop->fo_name,
		    flowop->fo_instance);
#endif

		if (strcmp(name, flowop->fo_name) == 0) {

			/* Add flowop to result list */
			if (result == NULL) {
				result = flowop;
				flowop->fo_resultnext = NULL;
			} else {
				flowop->fo_resultnext = result;
				result = flowop;
			}
		}			
		flowop = flowop->fo_next;
	}

	ipc_mutex_unlock(&filebench_shm->flowop_lock);


	return(result);
}

flowop_t *
flowop_find_one(char *name, int instance)
{
	flowop_t *result;
      
	result = flowop_find(name);

	while (result) {
		if ((strcmp(name, result->fo_name) == 0) &&
		    (instance == result->fo_instance))
			break;
		result = result->fo_next;
	}

	return(result);	
}




void
flowop_define_barrier(void)
{
	/* Upgrade to write lock to synchonize on start */
	pthread_rwlock_unlock(&filebench_shm->flowop_find_lock);
}

void
flowop_find_barrier(void)
{
	/* Block on wrlock to ensure find waits for all creates */
	pthread_rwlock_wrlock(&filebench_shm->flowop_find_lock);
	pthread_rwlock_unlock(&filebench_shm->flowop_find_lock);
}
