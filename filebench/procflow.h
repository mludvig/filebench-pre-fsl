/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */


#ifndef _PROCFLOW_H
#define _PROCFLOW_H

#include <config.h>

#include "vars.h"
#include "stats.h"

typedef struct procflow {
	char              pf_name[128];
	int               pf_instance;
	var_integer_t     pf_instances;
	int               pf_running;
	struct procflow   *pf_next;
	pid_t             pf_pid;
	struct threadflow *pf_threads;
        int               pf_attrs;
	var_integer_t     pf_nice;
	flowstat_t        pf_stats;
} procflow_t;

procflow_t *procflow_define(char *name, procflow_t *inherit, var_integer_t instances);
procflow_t *procflow_find(char *, int instance);
int        procflow_init();
int        procflow_shutdown();
void       procflow_iter(int (*cmd)(procflow_t *procflow, int first));
int        procflow_exec(char *name, int instance);
void       procflow_usage();
int        procflow_allstarted();

#endif
