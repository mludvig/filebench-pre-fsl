/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */


#ifndef _STATS_H
#define _STATS_H

#include "config.h"
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

var_t *stats_findvar(var_t *var, char *name);
vinteger_t kstats_read_cpu();
void stats_init();
void stats_clear();
void stats_snap();
void stats_dump(char *filename);
void stats_xmldump(char *filename);

#ifndef HAVE_HRTIME
//typedef uint64_t hrtime_t;
#define hrtime_t uint64_t
#endif

#define STATS_VAR "stats."

#define FLOW_MSTATES        4
#define FLOW_MSTATE_LAT     0          /* Total service time of op */
#define FLOW_MSTATE_CPU     1          /* On-cpu time of op */
#define FLOW_MSTATE_WAIT    2          /* Wait-time, excluding waiting for CPU */
#define FLOW_MSTATE_OHEAD   3          /* overhead time, around op */

typedef struct flowstats {
	int               fs_children;     /* Number of contributors */
	int               fs_active;       /* Number of active contributors */
	int               fs_count;        /* Number of ops */
	uint64_t          fs_rbytes;       /* Number of bytes  */
	uint64_t          fs_wbytes;       /* Number of bytes  */
	uint64_t          fs_bytes;        /* Number of bytes  */
	uint64_t          fs_rcount;       /* Number of ops */
	uint64_t          fs_wcount;       /* Number of ops */
	hrtime_t          fs_stime;        /* Time stats for flow started */
	hrtime_t          fs_etime;        /* Time stats for flow ended */
	hrtime_t          fs_mstate[FLOW_MSTATES]; /* Microstate breakdown of flow */
	hrtime_t          fs_syscpu;       /* System wide cpu, global only */
} flowstat_t;


#define IS_FLOW_IOP(x) (x->fo_stats.fs_rcount + x->fo_stats.fs_wcount)
#define STAT_IOPS(x)   ((x->fs_rcount) + (x->fs_wcount))
#define IS_FLOW_ACTIVE(x) (x->fo_stats.fs_count)
#define STAT_CPUTIME(x) (x->fs_cpu_op) 
#define STAT_OHEADTIME(x) (x->fs_cpu_ohead) 

/* Global statistics */
extern flowstat_t *globalstats;

#endif /* STATS_H */
