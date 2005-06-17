/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>

#include <stdio.h>
#include <sys/types.h>
#ifdef HAVE_STDINT_H
#include <stdint.h>
#endif

#ifndef _VARS_H
#define _VARS_H

typedef uint64_t    vinteger_t;
typedef vinteger_t * var_integer_t;
typedef char **      var_string_t;

typedef struct var {
	char        *var_name;
	int          var_type;
	struct var  *var_next;
        char        *var_string;
        vinteger_t   var_integer;
} var_t;

#define VAR_TYPE_DYNAMIC 1

vinteger_t *integer_alloc(vinteger_t integer);
char **string_alloc(char *string);
int var_assign_integer(char *name, vinteger_t integer);
vinteger_t *var_ref_integer(char *name);
int var_assign_string(char *name, char *string);
int var_assign_var(char *name, char *string);
char **var_ref_string(char *name);
var_t *var_find(char * name);
var_t *var_alloc(char *name);
char *var_to_string(char *name);
vinteger_t var_to_integer(char *name);
int integer_isset(var_integer_t);

#endif

