/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#include "vars.h"
#include "misc.h"
#include "utils.h"
#include "stats.h"
#include "eventgen.h"
#include "filebench.h"

var_t *var_find_dynamic(char *name);

int
integer_isset(var_integer_t v)
{
	if (v == NULL)
		return(0);

	return (*v);
}

var_integer_t
integer_alloc(vinteger_t integer)
{
	var_integer_t rtn;
	
	if ((rtn = (vinteger_t *)ipc_malloc(FILEBENCH_INTEGER)) == NULL) {
		filebench_log(LOG_ERROR, "Alloc integer failed");
		return(NULL);
	}
	
	*rtn = integer;

	filebench_log(LOG_DEBUG_IMPL, "Alloc integer %lld", integer);

	return(rtn);	  
}

var_string_t
string_alloc(char *string)
{
	char **rtn;
	
	if ((rtn = (char **)ipc_malloc(FILEBENCH_STRING)) == NULL) {
		filebench_log(LOG_ERROR, "Alloc string failed");
		return(NULL);
	}
	
	*rtn = ipc_stralloc(string);

	filebench_log(LOG_DEBUG_IMPL,
	    "Alloc string %s ptr %zx", 
	    string, rtn);

	return(rtn);	  
}


var_t *
var_alloc(char *name)
{
	var_t *var = NULL;
	var_t *prev = NULL;
	var_t *newvar;

	if ((newvar = (var_t *)ipc_malloc(FILEBENCH_VARIABLE)) == NULL) {
		filebench_log(LOG_ERROR, "Out of memory for variables");
		return(NULL);
	}
	memset(newvar, 0, sizeof(newvar));
	
	for (var = filebench_shm->var_list; var != NULL;
	     var = var->var_next)
		prev = var; /* Find end of list */
	if (prev != NULL)
		prev->var_next = newvar;
	else
		filebench_shm->var_list = newvar;

	if ((newvar->var_name = ipc_stralloc(name)) == NULL) {
		filebench_log(LOG_ERROR, "Out of memory for variables");
		return(NULL);
	}

	return(newvar);
}

static var_t *
var_alloc_dynamic(char *name)
{
	var_t *var = NULL;
	var_t *prev = NULL;
	var_t *newvar;

	if ((newvar = (var_t *)ipc_malloc(FILEBENCH_VARIABLE)) == NULL) {
		filebench_log(LOG_ERROR, "Out of memory for variables");
		return(NULL);
	}
	memset(newvar, 0, sizeof(newvar));
	
	for (var = filebench_shm->var_dyn_list; var != NULL;
	     var = var->var_next)
		prev = var; /* Find end of list */
	if (prev != NULL)
		prev->var_next = newvar;
	else
		filebench_shm->var_dyn_list = newvar;

	if ((newvar->var_name = ipc_stralloc(name)) == NULL) {
		filebench_log(LOG_ERROR, "Out of memory for variables");
		return(NULL);
	}

	return(newvar);
}

int
var_assign_integer(char *name, vinteger_t integer)
{
	var_t *var;

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_alloc(name);

	if (var == NULL) {
		filebench_log(LOG_ERROR, "Cannot assign variable %s",
		    name);
		return(-1);
	}

	var->var_integer = integer;

	filebench_log(LOG_DEBUG_SCRIPT, "Assign integer %s=%lld", name, integer);

	return(0);
}

vinteger_t *
var_ref_integer(char *name)
{
	var_t *var;

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_find_dynamic(name);

	if (var == NULL)
		var = var_alloc(name);

	if (var == NULL) {
		filebench_log(LOG_ERROR, "Invalid variable $%s",
		    name);
		filebench_shutdown(1);
	}

	return(&var->var_integer);

}

char *
var_to_string(char *name)
{
	var_t *var;
	char tmp[128];
	char *string;

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_find_dynamic(name);

	if (var == NULL)
		return(NULL);

	if (var->var_string)
		return(stralloc(var->var_string));
	
	sprintf(tmp, "%lld", var->var_integer);

	return (stralloc(tmp));
}

vinteger_t
var_to_integer(char *name)
{
	var_t *var;
	char tmp[128];

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_find_dynamic(name);

	if ((var != NULL) && (var->var_integer))
		return(var->var_integer);
	
	filebench_log(LOG_ERROR,
	    "Variable %s referenced before set", name);

	return (0);
}

int
var_assign_var(char *name, char *string)
{
	var_t *var;
	var_string_t str;

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_alloc(name);

	if (var == NULL) {
		filebench_log(LOG_ERROR, "Cannot assign variable %s",
		    name);
		return(-1);
	}

	if ((str = var_ref_string(string)) == NULL)
		return(-1);

	if ((var->var_string = ipc_stralloc(*str)) == NULL) {
		filebench_log(LOG_ERROR, "Cannot assign variable %s",
		    name);
		return(-1);
	}
	filebench_log(LOG_VERBOSE, "Assign string %s=%s", name, string);
	return(0);
}

int
var_assign_string(char *name, char *string)
{
	var_t *var;

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_alloc(name);

	if (var == NULL) {
		filebench_log(LOG_ERROR, "Cannot assign variable %s",
		    name);
		return(-1);
	}

	if ((var->var_string = ipc_stralloc(string)) == NULL) {
		filebench_log(LOG_ERROR, "Cannot assign variable %s",
		    name);
		return(-1);
	}
		
	filebench_log(LOG_DEBUG_SCRIPT, "Assign string %s=%s", name, string);

	return(0);
}

char **
var_ref_string(char *name)
{
	var_t *var;

	name += 1;

	if ((var = var_find(name)) == NULL)
		var = var_find_dynamic(name);

	if (var == NULL)
		var = var_alloc(name);

	if (var == NULL) {
		filebench_log(LOG_ERROR, "Cannot reference variable %s",
		    name);
		filebench_shutdown(1);
	}

	return(&var->var_string);
}

var_t *
var_find(char *name)
{
	var_t *var;

	for (var = filebench_shm->var_list; var != NULL;
	     var = var->var_next) {
		if (strcmp(var->var_name, name) == 0)
			return(var);
	}
	
	return(NULL);
}


static var_t *
var_find_internal(var_t *var)
{
	char *n = stralloc(var->var_name);
	char *name = n;
	var_t *rtn = NULL;

	name++;
	if (name[strlen(name) - 1] != '}')
		return(NULL);
	name[strlen(name) - 1] = 0;

	if (strncmp(name, STATS_VAR, strlen(STATS_VAR)) == 0) {
		rtn = stats_findvar(var, name + strlen(STATS_VAR));
	}

	if (strcmp(name, EVENTGEN_VAR) == 0) {
		rtn = eventgen_ratevar(var);
	}

	if (strcmp(name, DATE_VAR) == 0) {
		rtn = date_var(var);
	}

	if (strcmp(name, SCRIPT_VAR) == 0) {
		rtn = script_var(var);
	}

	if (strcmp(name, HOST_VAR) == 0) {
		rtn = host_var(var);
	}

	free(n);

	return(rtn);
}

static var_t *
var_find_environment(var_t *var)
{
	char *n = stralloc(var->var_name);
	char *name = n;
	char s[128];

	name++;
	if (name[strlen(name) - 1] != ')')
		return(NULL);
	name[strlen(name) - 1] = 0;

	if ((var->var_string = getenv(name)) != NULL) {
		free(n);
		return(var);
	} else {
		free(n);
		return(NULL);
	}
}

/* Look up a special variable */
var_t *
var_find_dynamic(char *name)
{
	var_t *var = NULL;
	var_t *v = filebench_shm->var_dyn_list;
	var_t *rtn;

	/*
	 * Lookup a reference to the var handle for this
	 * special var
	 */
	for (v = filebench_shm->var_dyn_list; v != NULL;
	     v = v->var_next) {
		if (strcmp(v->var_name, name) == 0) {
			var = v;
			break;
		}
	}

	if (var == NULL)
		var = var_alloc_dynamic(name);

	/* Internal system control variable */
	if (*name == '{') {
		rtn = var_find_internal(var);
		if (rtn == NULL)
			filebench_log(LOG_ERROR,
			    "Cannot find internal variable %s",
			    var->var_name);
		return(rtn);
	}

	/* Lookup variable in environment */
	if (*name == '(') {
		rtn = var_find_environment(var);
		if (rtn == NULL)
			filebench_log(LOG_ERROR,
			    "Cannot find environment variable %s",
			    var->var_name);
		return(rtn);
	}

	return(NULL);
}
