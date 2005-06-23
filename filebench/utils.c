/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <limits.h>
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>
#include <stdio.h>
#include <errno.h>
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif
#include "utils.h"
#include "parsertypes.h"

static const char PNAME_FMT[] = "%s: ";
static const char ERRNO_FMT[] = ": %s\n";

static const char *pname;

char *
stralloc(char *str)
{
	char *newstr;
	
	if ((newstr = malloc(strlen(str) + 1)) == NULL) {
		return(NULL);
	}
	strcpy(newstr, str);
	return (newstr);
}

const char *
getpname(const char *arg0)
{
	const char *p = strrchr(arg0, '/');

	if (p == NULL)
		p = arg0;
	else
		p++;

	pname = p;
	return (p);
}
