/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#ifndef _FILEBENCH_H
#define _FILEBENCH_H

#include <config.h>

#include <stdio.h>
#include <string.h>


#include "vars.h"
#include "misc.h"
#include "flowop.h"
#include "ipc.h"

#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif


#ifdef __STDC__
#include <stdarg.h>
#define __V(x)  x
#ifndef __P
#define __P(x)  x
#endif
#else
#include <varargs.h>
#define __V(x)  (va_alist) va_dcl
#define __P(x)  ()
#define const
#endif

#include <sys/times.h>


extern pid_t pid;
extern int errno;
extern char *execname;
extern int noproc;

void filebench_init();
void filebench_log __V((int level, const char *fmt, ...));
void filebench_shutdown(int error);

#ifdef HAVE_SYS_INT_LIMITS_H
#include <sys/int_limits.h>
#endif /* HAVE_SYS_INT_LIMITS_H */

#ifndef HAVE_UINT64_MAX
#define UINT64_MAX (((off64_t)1UL<<63UL) - 1UL)
#endif

#define FILEBENCH_RANDMAX64 UINT64_MAX
#define FILEBENCH_RANDMAX32 UINT32_MAX

#if defined(_LP64) || (__WORDSIZE == 64)
#define filebench_randomno filebench_randomno64
#define FILEBENCH_RANDMAX FILEBENCH_RANDMAX64
#else
#define filebench_randomno filebench_randomno32
#define FILEBENCH_RANDMAX FILEBENCH_RANDMAX32
#endif
uint32_t filebench_randomno32();
uint64_t filebench_randomno64();

#define KB (1024LL)
#define MB (KB * KB)
#define GB (KB * MB)

#ifndef MIN
#define MIN(x, y)               ((x) < (y) ? (x) : (y))
#endif

#endif

/* For MacOSX */
#ifndef HAVE_OFF64_T
#define mmap64 mmap
#define off64_t off_t
#define open64 open
#define stat64 stat
#define pread64 pread
#define pwrite64 pwrite
#define lseek64 lseek
#define fstat64 fstat
#endif

