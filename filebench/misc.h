/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>

#include <stdio.h>
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

#ifndef _MISC_H
#define _MISC_H

#include <sys/times.h>

#define DATE_VAR "date"
#define SCRIPT_VAR "scriptname"
#define HOST_VAR "hostname"

#ifndef HAVE_HRTIME
uint64_t gethrtime();
#define hrtime_t uint64_t
#define FSECS (double)100.0
#else
#define FSECS (double)1000000000.0
#endif

#define LOG_INFO 1
#define LOG_VERBOSE 2
#define LOG_DEBUG_SCRIPT 3
#define LOG_DEBUG_IMPL 5
#define LOG_DEBUG_NEVER 10
#define LOG_LOG 1000
#define LOG_DUMP 1001
#define LOG_FATAL 999
#define LOG_ERROR 0

var_t *date_var(var_t *var);
var_t *script_var(var_t *var);
var_t *host_var(var_t *var);

#endif
