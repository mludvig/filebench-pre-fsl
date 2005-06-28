/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <signal.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/wait.h>

#include "procflow.h"
#include "filebench.h"
#include "flowop.h"
#include "ipc.h"

pid_t pid;

static procflow_t *procflow_define_common(procflow_t **list, char *name,
    procflow_t *inherit, int instance);

void
procflow_usage()
{
	fprintf(stderr, "define process name=<name>[,instances=<count>]\n");
	fprintf(stderr, "{\n");
	fprintf(stderr, "  thread ...\n");
	fprintf(stderr, "  thread ...\n");
	fprintf(stderr, "  thread ...\n");
	fprintf(stderr, "}\n");
	fprintf(stderr, "\n");
	fprintf(stderr, "\n");
}

int
procflow_createproc(procflow_t *procflow)
{
	int fp;
	char instance[128];
	char shmaddr[128];
	char procname[128];
	pid_t pid;
	char syscmd[1024];

#ifdef USE_PROCESS_MODEL

	sprintf(instance, "%d", procflow->pf_instance);
	sprintf(procname, "%s", procflow->pf_name);
#if defined(_LP64) || (__WORDSIZE == 64)
	sprintf(shmaddr, "%llx", filebench_shm);
#else
	sprintf(shmaddr, "%x", filebench_shm);
#endif      
	filebench_log(LOG_DEBUG_IMPL, "creating process %s",
	    procflow->pf_name);

	procflow->pf_running = 0;

#ifdef HAVE_FORK1
 	if ((pid = fork1()) < 0) {
		filebench_log(LOG_ERROR,
		    "procflow_createproc fork failed: %s",
		    strerror(errno));
		return(-1);
	}
#else
 	if ((pid = fork()) < 0) {
		filebench_log(LOG_ERROR,
		    "procflow_createproc fork failed: %s",
		    strerror(errno));
		return(-1);
	}
#endif /* HAVE_FORK1 */

	if (pid == 0) {
		sigignore(SIGINT);
		filebench_log(LOG_DEBUG_SCRIPT,
		    "Starting %s-%d", procflow->pf_name, 
		    procflow->pf_instance);
		/* Child */

#ifdef USE_SYSTEM
		sprintf(syscmd, "%s -a %s -i %s -s %s",
		    execname,
		    procname,
		    instance,
		    shmaddr);
		if (system(syscmd) < 0) {
			filebench_log(LOG_ERROR, 
			    "procflow exec proc failed: %s",
			    strerror(errno));
			filebench_shutdown(1);
		}
			
#else
		if (execl(execname, procname, "-a",
			procname,
			"-i", instance, "-s", shmaddr, "-m", shmpath, NULL) < 0) {
			filebench_log(LOG_ERROR, 
			    "procflow exec proc failed: %s",
			    strerror(errno));
			filebench_shutdown(1);
		}
#endif
		exit(1);
	} else {
		procflow->pf_pid = pid;
	}
#else
	procflow->pf_running = 1;
        if (pthread_create(&procflow->pf_tid, NULL,
                (void *(*)(void*))threadflow_init, procflow) != 0) {
                filebench_log(LOG_ERROR, "proc-thread create failed");
		procflow->pf_running = 0;
	}
#endif
	filebench_log(LOG_DEBUG_IMPL, "procflow_createproc created pid %d", pid);

	return(0);
}

#ifdef USE_PROCESS_MODEL
int
procflow_exec(char *name, int instance)
{
	procflow_t *procflow;
	int proc_nice;
#ifdef HAVE_SETRLIMIT
	struct rlimit rlp;
#endif

	filebench_log(LOG_DEBUG_IMPL,
	    "procflow_execproc %s-%d", 
	    name, instance);

	if ((procflow = procflow_find(name, instance)) == NULL) {
		filebench_log(LOG_ERROR, 
		    "procflow_createproc could not find %s-%d",
		    name, instance);
		return(-1);
	}
	procflow->pf_pid = pid;

	filebench_log(LOG_DEBUG_IMPL,
	    "Started up %s pid %d", procflow->pf_name, pid);

	filebench_log(LOG_DEBUG_IMPL,
	    "nice = %llx", procflow->pf_nice);

	proc_nice = *procflow->pf_nice;
	filebench_log(LOG_DEBUG_IMPL, "Setting pri of %s-%d to %d",
	    name, instance, nice(proc_nice + 10));

	procflow->pf_running = 1;

#ifdef HAVE_SETRLIMIT
	/* Get resource limits */
	getrlimit(RLIMIT_NOFILE, &rlp);
	filebench_log(LOG_DEBUG_SCRIPT, "%d file descriptors", rlp.rlim_cur);
#endif
	
	threadflow_init(procflow);
	filebench_log(LOG_DEBUG_IMPL, "procflow_createproc exiting...");
	procflow->pf_running = 0;
	exit(0);
}
#endif


int
procflow_init()
{
	procflow_t *procflow = filebench_shm->proclist;
	procflow_t *newproc;
	int ret = 0;
	int i;

	filebench_log(LOG_DEBUG_IMPL,
	    "procflow_init %s, %lld", 
	    procflow->pf_name, *(procflow->pf_instances));

	ipc_mutex_lock(&filebench_shm->procflow_lock);	

	while (procflow) {
		filebench_log(LOG_INFO,
		    "Starting %lld %s instances",
		    *(procflow->pf_instances),
		procflow->pf_name);

		/* Create instances of procflow */
		for (i = 0; i < *procflow->pf_instances; i++) {
			/* Create processes */
			newproc = 
			    procflow_define_common(&filebench_shm->proclist,
			    procflow->pf_name,
				procflow, i + 1);
			if (newproc == NULL)
				return (-1);
			ret += procflow_createproc(newproc);
		}
		procflow = procflow->pf_next;
	}

	ipc_mutex_unlock(&filebench_shm->procflow_lock);	

	return(ret);
}

#ifdef USE_PROCESS_MODEL
static void
procflow_wait(pid_t pid)
{
	pid_t wpid;
	int stat;
	
	waitpid(pid, &stat, 0);
	while ((wpid = waitpid(getpid() * -1, &stat, WNOHANG)) > 0)
		filebench_log(LOG_DEBUG_IMPL, "Waited for pid %lld", wpid);
}
#endif

int
procflow_delete(procflow_t *procflow)
{
	procflow_t *entry = filebench_shm->proclist;
	int stat;
	int waits;

	while (entry) {
		threadflow_delete_all(&procflow->pf_threads);
		entry = entry->pf_next;
	}
		
	entry = filebench_shm->proclist;

	if (entry == procflow) {
		/* First on list */
		filebench_log(LOG_DEBUG_SCRIPT,
		    "Deleted proc: (%s-%d) pid %d",
		    procflow->pf_name,
		    procflow->pf_instance,
		    procflow->pf_pid);
		waits = 0;
		while (procflow->pf_running == 1) {
			ipc_mutex_unlock(&filebench_shm->procflow_lock);	
			filebench_log(LOG_DEBUG_SCRIPT, "Waiting for process %s-%d %d",
			    procflow->pf_name,
			    procflow->pf_instance,
			    procflow->pf_pid);
			
			sleep(1);
			waits++;
			ipc_mutex_lock(&filebench_shm->procflow_lock);				
#ifdef USE_PROCESS_MODEL
			if (waits > 10) {
				kill(procflow->pf_pid, SIGKILL);
				filebench_log(LOG_DEBUG_SCRIPT, "Had to kill process %s-%d %d!",
				    procflow->pf_name,
				    procflow->pf_instance,
				    procflow->pf_pid);
				procflow->pf_running = 0;
			}
#endif

		}

#ifdef USE_PROCESS_MODEL
		procflow_wait(procflow->pf_pid);
#endif
		filebench_shm->proclist = procflow->pf_next;
		ipc_free(FILEBENCH_PROCFLOW, (char *)procflow);
		return(0);
	}

	while (entry->pf_next) {
		filebench_log(LOG_DEBUG_SCRIPT,
		    "Delete proc: (%s-%d) == (%s-%d)",
		    entry->pf_name,
		    entry->pf_instance,
		    procflow->pf_name,
		    procflow->pf_instance);
		
		if (procflow == entry->pf_next) {
			waits = 0;
			while (entry->pf_next->pf_running == 1) {
				ipc_mutex_unlock(&filebench_shm->procflow_lock);	
				filebench_log(LOG_DEBUG_SCRIPT, "Waiting for process %s-%d %d",
				    entry->pf_next->pf_name,
				    entry->pf_next->pf_instance,
				    entry->pf_next->pf_pid);
				
				sleep(1);
				waits++;
				ipc_mutex_lock(&filebench_shm->procflow_lock);	
#ifdef USE_PROCESS_MODEL
				if (waits > 3) {
					kill(entry->pf_next->pf_pid, SIGKILL);
					filebench_log(LOG_DEBUG_SCRIPT, "Had to kill process %s-%d %d!",
					    entry->pf_next->pf_name,
					    entry->pf_next->pf_instance,
					    entry->pf_next->pf_pid);
					entry->pf_next->pf_running = 0;
				}				
#endif
			}

			/* Delete */
			filebench_log(LOG_DEBUG_IMPL,
			    "Deleted proc: (%s-%d) pid %d", 
			    entry->pf_next->pf_name,
			    entry->pf_next->pf_instance,
			    entry->pf_next->pf_pid);
#ifdef USE_PROCESS_MODEL
			procflow_wait(entry->pf_next->pf_pid);
#endif
			ipc_free(FILEBENCH_PROCFLOW, (char *)procflow);
			entry->pf_next = entry->pf_next->pf_next;
			return(0);
		}		
		entry = entry->pf_next;
	}
	
	return(-1);
}


int
procflow_allstarted()
{
	procflow_t *procflow = filebench_shm->proclist;
	int ret = 0;
	int waits;

	ipc_mutex_lock(&filebench_shm->procflow_lock);	

	sleep(1);

	while (procflow) {
		if (procflow->pf_instance &&
			(procflow->pf_instance == FLOW_MASTER)) {
			procflow = procflow->pf_next;		
			continue;
		}

		waits = 10;
		while (waits && procflow->pf_running == 0) {
			ipc_mutex_unlock(&filebench_shm->procflow_lock);	
			if (waits < 3)
				filebench_log(LOG_INFO, "Waiting for process %s-%d %d",
				    procflow->pf_name,
				    procflow->pf_instance,
				    procflow->pf_pid);

			sleep(3);
			waits--;
			ipc_mutex_lock(&filebench_shm->procflow_lock); 
		}

		if (waits == 0)
			filebench_log(LOG_INFO, "Failed to start process %s-%d",
			    procflow->pf_name,
			    procflow->pf_instance);

		threadflow_allstarted(procflow->pf_pid, procflow->pf_threads);

		procflow = procflow->pf_next;
	}

	filebench_shm->allrunning = 1;
	ipc_mutex_unlock(&filebench_shm->procflow_lock);	


	return(ret);
}


int
procflow_shutdown()
{
	procflow_t *procflow = filebench_shm->proclist;
	int ret = 0;

	ipc_mutex_lock(&filebench_shm->procflow_lock);	
	filebench_shm->allrunning = 0;
	filebench_shm->f_abort = 1;

	while (procflow) {
		if (procflow->pf_instance &&
			(procflow->pf_instance == FLOW_MASTER)) {
			procflow = procflow->pf_next;		
			continue;
		}
		filebench_log(LOG_DEBUG_IMPL, "Deleting process %s-%d %d",
		    procflow->pf_name,
		    procflow->pf_instance,
		    procflow->pf_pid);
		procflow_delete(procflow);
		procflow = procflow->pf_next;
	}

	filebench_shm->f_abort = 0;

	ipc_mutex_unlock(&filebench_shm->procflow_lock);	


	return(ret);
}


/* Create an in-memory process object */
static procflow_t *
procflow_define_common(procflow_t **list, char *name, 
    procflow_t *inherit, int instance)
{
	procflow_t *procflow;

	if (name == NULL)
		return NULL;

	procflow = (procflow_t *)ipc_malloc(FILEBENCH_PROCFLOW);

	if (procflow == NULL)
		return (NULL);

	if (inherit)
		memcpy(procflow, inherit, sizeof(procflow_t));
	else {
		memset(procflow, 0, sizeof(procflow_t));
	}
	
	procflow->pf_instance = instance;
	strcpy(procflow->pf_name, name);

	filebench_log(LOG_DEBUG_IMPL, "defining process %s-%d", name, instance);

	filebench_log(LOG_DEBUG_IMPL, "process %s-%d proclist %zx", 
	    name, instance, filebench_shm->proclist);
	/* Add procflow to list, lock is being held already */
	if (*list == NULL) {
		*list = procflow;
		procflow->pf_next = NULL;
	} else {
		procflow->pf_next = *list;
		*list = procflow;
	}
	filebench_log(LOG_DEBUG_IMPL, "process %s-%d proclist %zx",
	    name, instance, filebench_shm->proclist);

	return(procflow);
}

/* 
 * Create an in-memory process object as described by the syntax
 *
 * procflow_lock must be held 
 *
 */
procflow_t *
procflow_define(char *name, procflow_t *inherit, var_integer_t instances)
{
	procflow_t *procflow;


	ipc_mutex_lock(&filebench_shm->procflow_lock);	

	procflow = procflow_define_common(&filebench_shm->proclist,
	    name, inherit, FLOW_MASTER);
	procflow->pf_instances = instances;

	ipc_mutex_unlock(&filebench_shm->procflow_lock);	

	return(procflow);       
}

/* Find a procflow from as described by the syntax */
procflow_t *
procflow_find(char *name, int instance)
{
	procflow_t *procflow = filebench_shm->proclist;

	filebench_log(LOG_DEBUG_IMPL, "Find: (%s-%d) proclist = %zx",
		      name, instance, procflow);

	ipc_mutex_lock(&filebench_shm->procflow_lock);	

	while (procflow) {
		filebench_log(LOG_DEBUG_IMPL, "Find: (%s-%d) == (%s-%d)",
		    name, instance,
		    procflow->pf_name,
		    procflow->pf_instance);
		if ((strcmp(name, procflow->pf_name) == 0) &&
		    (instance == procflow->pf_instance)) {

			ipc_mutex_unlock(&filebench_shm->procflow_lock);	

			return(procflow);
		}
		procflow = procflow->pf_next;
	}

	ipc_mutex_unlock(&filebench_shm->procflow_lock);	

	return(NULL);
}

void
procflow_iter(int (*cmd)(procflow_t *procflow, int first))
{
	procflow_t *procflow = filebench_shm->proclist;
	int count = 0;

	ipc_mutex_lock(&filebench_shm->procflow_lock);	

	while (procflow) {
		cmd(procflow, count == 0);
		procflow = procflow->pf_next;
		count++;
	}

	ipc_mutex_unlock(&filebench_shm->procflow_lock);	

	return;
}

int
procflow_print(procflow_t *procflow, int first)
{
	if (first) {
		printf("%10s %32s %8s\n",
		    "File Name",
		    "Path Name",
		    "Size");
	}

	printf("%10s\n",
	       procflow->pf_name);
	return(0);
}


flowstat_t *
procflow_stats()
{	
	return (0);
	    
}

