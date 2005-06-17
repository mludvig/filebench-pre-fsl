/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <sys/time.h>
#include "vars.h"
#include "eventgen.h"
#include "flowop.h"
#include "ipc.h"

void
eventgen_usage()
{
	fprintf(stderr, "eventgen rate=<rate>\n");
	fprintf(stderr, "\n");
}

/* Producer side of rate eventgen */
void
eventgen_thread(void)
{
	struct timespec sleeptime;
	hrtime_t last;
	hrtime_t delta;
	int count;

	last = gethrtime();		
	while(1) {
		if (filebench_shm->eventgen_hz == 0) {
			sleep(1);
			continue;
		}
		/* Sleep for 10xperiod */	
		sleeptime.tv_sec = 0;
		sleeptime.tv_nsec = 10000000000UL / filebench_shm->eventgen_hz;
		if (sleeptime.tv_nsec < 1000UL)
			sleeptime.tv_nsec = 1000UL;
		sleeptime.tv_sec = sleeptime.tv_nsec / 1000000000UL;
		if (sleeptime.tv_sec > 0)
			sleeptime.tv_nsec -= (sleeptime.tv_sec * 1000000000UL);
		nanosleep(&sleeptime, NULL);
		delta = gethrtime() - last;
		last = gethrtime();
		count = (filebench_shm->eventgen_hz * delta) / 1000000000;

		filebench_log(LOG_DEBUG_SCRIPT, 
			"delta %lldms count %d", delta / 1000000, count);

		/* Send 'count' events */
		ipc_mutex_lock(&filebench_shm->eventgen_lock);
		/* Keep the producer with a max of 5 second depth */
		if (filebench_shm->eventgen_q < (5 * filebench_shm->eventgen_hz))
			filebench_shm->eventgen_q += count;

		pthread_cond_signal(&filebench_shm->eventgen_cv);

#ifdef NEVER
		if (filebench_shm->eventgen_q <= count) {
			while(count) {
				pthread_cond_signal(&filebench_shm->eventgen_cv);
				count--;
			}
		}
#endif
		ipc_mutex_unlock(&filebench_shm->eventgen_lock);

#ifdef NEVER
		/* Old mechanism with cap */
		while(count) {
			ipc_mutex_lock(&filebench_shm->eventgen_lock);
			/* Keep the producer with a max of 5 second depth */
			if (filebench_shm->eventgen_q <
			    (5 * filebench_shm->eventgen_hz))
				filebench_shm->eventgen_q++;
			count--;
			pthread_cond_signal(&filebench_shm->eventgen_cv);
			ipc_mutex_unlock(&filebench_shm->eventgen_lock);
		}
#endif
	}
}

void
eventgen_init()
{
	/* Linux does not like it if the first
	 * argument to pthread_create is null. It actually
	 * segv's. -neel
	 */
	pthread_t tid;

	if (pthread_create(&tid, NULL, (void *(*)(void*))eventgen_thread, 0) != 0) 
	{
		filebench_log(LOG_ERROR, "create timer thread failed: %s",
		    strerror(errno));
		filebench_shutdown(1);
	}
	
}

var_t *
eventgen_ratevar(var_t *var)
{
	var->var_integer = filebench_shm->eventgen_hz;
	return(var);
}

void
eventgen_setrate(vinteger_t rate)
{
	filebench_shm->eventgen_hz = rate;
}

void
eventgen_reset(void)
{
	filebench_shm->eventgen_q = 0;
}
