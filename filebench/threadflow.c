/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include "config.h"
#include <pthread.h>
#ifdef HAVE_LWPS
#include <sys/lwp.h>
#endif
#include <signal.h>
#include "threadflow.h"
#include "filebench.h"
#include "flowop.h"
#include "ipc.h"

static threadflow_t * threadflow_define_common(procflow_t *procflow, 
    char *name, threadflow_t *inherit, int instance);

void
threadflow_usage()
{
	fprintf(stderr, "  thread  name=<name>[,instances=<count>]\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "  {\n");
	fprintf(stderr, "    flowop ...\n");
	fprintf(stderr, "    flowop ...\n");
	fprintf(stderr, "    flowop ...\n");
	fprintf(stderr, "  }\n");
	fprintf(stderr, "\n");
}

int
threadflow_createthread(threadflow_t *threadflow)
{
	int fp = 0;

	filebench_log(LOG_DEBUG_SCRIPT, "Creating thread %s, memory = %ld", 
	    threadflow->tf_name,
	    *threadflow->tf_memsize);

	if (threadflow->tf_attrs & THREADFLOW_USEISM) {
		filebench_shm->shm_required += (*threadflow->tf_memsize);
	}

	if (pthread_create(&threadflow->tf_tid, NULL, 
		(void *(*)(void*))flowop_start, 
	    threadflow) != 0) {
		filebench_log(LOG_ERROR, "thread create failed");
		filebench_shutdown(1);
	}

	return(fp < 0);
}

static procflow_t *my_procflow;

void
threadflow_cancel(int arg)
{
	threadflow_t *threadflow = my_procflow->pf_threads;

#ifdef HAVE_LWPS
	filebench_log(LOG_DEBUG_IMPL, "Thread signal handler on tid %d", 
	    _lwp_self());
#endif

	my_procflow->pf_running = 0;
	exit(0);
	
	while (threadflow) {
		if (threadflow->tf_tid) {
		        pthread_cancel(threadflow->tf_tid);
			filebench_log(LOG_DEBUG_IMPL, "Thread %d cancelled...",
				threadflow->tf_tid);
		}
		threadflow = threadflow->tf_next;
	}
}

int
threadflow_init(procflow_t *procflow)
{
	threadflow_t *threadflow = procflow->pf_threads;
	threadflow_t *newthread;
	int ret = 0;
	int i;

	ipc_mutex_lock(&filebench_shm->threadflow_lock);
	my_procflow = procflow;
	signal(SIGUSR1, threadflow_cancel);

	while (threadflow) {

		filebench_log(LOG_VERBOSE,
		    "Starting %lld %s threads",
		    *(threadflow->tf_instances),
		    threadflow->tf_name);

		for (i = 1; i < *threadflow->tf_instances; i++) {
			/* Create threads */
			newthread = 
			    threadflow_define_common(procflow,
				threadflow->tf_name,
				threadflow, i + 1);
			if (newthread == NULL)
				return (-1);
			ret += threadflow_createthread(newthread);
		}

		newthread = threadflow_define_common(procflow,
		    threadflow->tf_name,
		    threadflow, 1);

		if (newthread == NULL)
			return (-1);

		/* Create threads */
		ret += threadflow_createthread(newthread);
		
		threadflow = threadflow->tf_next;
	}

	threadflow = procflow->pf_threads;

	ipc_mutex_unlock(&filebench_shm->threadflow_lock);	

	while (threadflow) {
		if (threadflow->tf_tid)
		        pthread_join(threadflow->tf_tid, NULL);
		filebench_log(LOG_DEBUG_IMPL, "Thread exited...");
		threadflow = threadflow->tf_next;
	}

	procflow->pf_running = 0;

	return(ret);
}

static int
threadflow_kill(threadflow_t *threadflow)
{
	/* Tell thread to finish */
	threadflow->tf_abort = 1;
#ifdef HAVE_SIGSEND
	sigsend(P_PID, threadflow->tf_process->pf_pid, SIGUSR1);
#else
	kill(threadflow->tf_process->pf_pid, SIGUSR1);
#endif
	return (0);

}

int
threadflow_delete(threadflow_t **threadlist, threadflow_t *threadflow)
{
	threadflow_t *entry = *threadlist;

	filebench_log(LOG_DEBUG_IMPL, "Deleting thread: (%s-%d)",
	    threadflow->tf_name,
	    threadflow->tf_instance);

	if (threadflow->tf_attrs & THREADFLOW_USEISM) {
		filebench_shm->shm_required -= (*threadflow->tf_memsize);
	}

	if (threadflow == *threadlist) {
		/* First on list */
		filebench_log(LOG_DEBUG_IMPL, "Deleted thread: (%s-%d)",
		    threadflow->tf_name,
		    threadflow->tf_instance);

		threadflow_kill(threadflow);
		flowop_delete_all(&threadflow->tf_ops);
		*threadlist = threadflow->tf_next;
		ipc_free(FILEBENCH_THREADFLOW, (char *)threadflow);
		return(0);
	}

	while (entry->tf_next) {
		filebench_log(LOG_DEBUG_IMPL, 
		    "Delete thread: (%s-%d) == (%s-%d)",
		    entry->tf_next->tf_name,
		    entry->tf_next->tf_instance,
		    threadflow->tf_name,
		    threadflow->tf_instance);
		
		if (threadflow == entry->tf_next) {
			/* Delete */
			filebench_log(LOG_DEBUG_IMPL, 
			    "Deleted thread: (%s-%d)",
			    entry->tf_next->tf_name,
			    entry->tf_next->tf_instance);
			threadflow_kill(entry->tf_next);
			flowop_delete_all(&entry->tf_next->tf_ops);
			ipc_free(FILEBENCH_THREADFLOW, (char *)threadflow);
			entry->tf_next = entry->tf_next->tf_next;
			return(0);
		}
		entry = entry->tf_next;
	}
	
	return(-1);
}

int
threadflow_delete_all(threadflow_t **threadlist)
{
	threadflow_t *threadflow = *threadlist;

	ipc_mutex_lock(&filebench_shm->threadflow_lock);	

	filebench_log(LOG_DEBUG_IMPL, "Deleting all threads");

	while (threadflow) {
		if (threadflow->tf_instance && 
			(threadflow->tf_instance == FLOW_MASTER)) {
			threadflow = threadflow->tf_next;
			continue;
		}
		threadflow_delete(threadlist, threadflow);
		threadflow = threadflow->tf_next;
	}

	ipc_mutex_unlock(&filebench_shm->threadflow_lock);	
	
}

int
threadflow_allstarted(pid_t pid, threadflow_t *threadflow)
{
	int ret = 0;
	int waits;

	ipc_mutex_lock(&filebench_shm->threadflow_lock);	

	while (threadflow) {
		if ((threadflow->tf_instance == 0) ||
			(threadflow->tf_instance == FLOW_MASTER)) {
			threadflow = threadflow->tf_next;		
			continue;
		}

		filebench_log(LOG_DEBUG_IMPL, "Checking pid %d thread %s-%d",
		    pid,
		    threadflow->tf_name,
		    threadflow->tf_instance);

		waits = 10;
		while (waits && threadflow->tf_running == 0) {
			ipc_mutex_unlock(&filebench_shm->threadflow_lock);	
			if (waits < 3)
				filebench_log(LOG_INFO, 
				    "Waiting for pid %d thread %s-%d",
				    pid,
				    threadflow->tf_name,
				    threadflow->tf_instance);

			sleep(1);
			ipc_mutex_lock(&filebench_shm->threadflow_lock);	
			waits--;
		}

		threadflow = threadflow->tf_next;
	}

	ipc_mutex_unlock(&filebench_shm->threadflow_lock);	

	return(ret);
}

/* Create an in-memory thread object linked to parent procflow */
static threadflow_t *
threadflow_define_common(procflow_t *procflow, char *name,
    threadflow_t *inherit, int instance)
{
	threadflow_t *threadflow;
	threadflow_t **threadlistp = &procflow->pf_threads;

	if (name == NULL)
		return NULL;

	threadflow = (threadflow_t *)ipc_malloc(FILEBENCH_THREADFLOW);

	if (threadflow == NULL)
		return (NULL);

	if (inherit)
		memcpy(threadflow, inherit, sizeof(threadflow_t));
	else {
		memset(threadflow, 0, sizeof(threadflow_t));
	}

	threadflow->tf_utid = ++filebench_shm->utid;
	
	threadflow->tf_instance = instance;
	strcpy(threadflow->tf_name, name);
	threadflow->tf_process = procflow;

	filebench_log(LOG_DEBUG_IMPL, "Defining thread %s-%d", 
	    name, instance);

	/* Add threadflow to list */
	if (*threadlistp == NULL) {
		*threadlistp = threadflow;
		threadflow->tf_next = NULL;
	} else {
		threadflow->tf_next = *threadlistp;
		*threadlistp = threadflow;
	}

	return(threadflow);
}

/* Create an in-memory threadess object as described by the syntax */
threadflow_t *
threadflow_define(procflow_t *procflow, char *name,
    threadflow_t *inherit, var_integer_t instances)
{
	threadflow_t *threadflow;

	ipc_mutex_lock(&filebench_shm->threadflow_lock);	

	threadflow = threadflow_define_common(procflow, name,
	    inherit, FLOW_MASTER);
	threadflow->tf_instances = instances;

	ipc_mutex_unlock(&filebench_shm->threadflow_lock);	

	return(threadflow);       
}


threadflow_t *
threadflow_find(threadflow_t *threadlist, char *name)
{
	threadflow_t *threadflow = threadlist;

	ipc_mutex_lock(&filebench_shm->threadflow_lock);	

	while (threadflow) {
		if (strcmp(name, threadflow->tf_name) == 0) {

			ipc_mutex_unlock(&filebench_shm->threadflow_lock);	

			return(threadflow);
		}
		threadflow = threadflow->tf_next;
	}

	ipc_mutex_unlock(&filebench_shm->threadflow_lock);	


	return(NULL);
}

void
threadflow_iter(threadflow_t *threadlist, 
	int (*cmd)(threadflow_t *threadflow, int first))
{
	threadflow_t *threadflow = threadlist;
	int count = 0;

	ipc_mutex_lock(&filebench_shm->threadflow_lock);	

	while (threadflow) {
		cmd(threadflow, count == 0);
		threadflow = threadflow->tf_next;
		count++;
	}

	ipc_mutex_unlock(&filebench_shm->threadflow_lock);	


	return;
}

int
threadflow_print(threadflow_t *threadflow, int first)
{
	if (first) {
		printf("%10s %32s\n",
		    "Thread Name",
		       "Proc Name");
	}

	printf("%10s\n",
	       threadflow->tf_name);
	return(0);
}
