/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#ifndef	_UTILS_H
#define	_UTILS_H

#pragma ident	"@(#)utils.h	1.3	03/09/19 SMI"

#include <config.h>

#include <sys/types.h>

#ifdef	__cplusplus
extern "C" {
#endif


#define	E_PO_SUCCESS	0		/* Exit status for success */
#define	E_ERROR		1		/* Exit status for error */
#define	E_USAGE		2		/* Exit status for usage error */

extern char *stralloc(char *str);
extern const char *get_errstr(void);
extern const char *get_errstr_err(int, int);
extern void warn(const char *, ...);
extern void die(const char *, ...);
extern const char *getpname(const char *);

#ifdef	__cplusplus
}
#endif

#endif	/* _UTILS_H */
