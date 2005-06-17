/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <config.h>
#include "vars.h"

void eventgen_thread(void);
void eventgen_init(void);
void eventgen_setrate(vinteger_t rate);
var_t *eventgen_ratevar(var_t *var);
void eventgen_usage();
void eventgen_reset();

#define EVENTGEN_VAR "rate"
