/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <stdio.h>
#include <fcntl.h>
#include <limits.h>
#include <time.h>
#include <libgen.h>
#include <unistd.h>
#include <strings.h>
#include "filebench.h"
#include "ipc.h"
#include "eventgen.h"
#include "utils.h"

#if !defined(sun)  && defined(USE_RDTSC)
/* Lets us use the rdtsc instruction to get highres time.
 * Thanks to libmicro
 */
static double	mhz = 0;
__inline__ long long
rdtsc(void)
{
    unsigned long long x;
    __asm__ volatile(".byte 0x0f, 0x31" : "=A" (x));
    return (x);
}

uint64_t
gethrtime() 
{
   //convert to nanosecs and return
   return (rdtsc() / mhz / 1.0e+4);
}

static double
parse_cpu_mhz()
{
	/* Parse the following from /proc/cpuinfo.
	 * cpu MHz		: 2191.563
	 */
	FILE *cpuinfo;
	double hertz = -1;
	char buffer[80], *token;
	if((cpuinfo = fopen("/proc/cpuinfo", "r")) == NULL){
		 filebench_log(LOG_ERROR, "open /proc/cpuinfo failed: %s",
			strerror(errno));
		filebench_shutdown(1);
	}
	while(!feof(cpuinfo)){
		fgets(buffer, 80, cpuinfo);
		if(strlen(buffer) == 0) continue;
		if(strncasecmp(buffer,"cpu MHz", 7) == 0){
			token = strtok(buffer, ":");
			if(token != NULL){
				token = strtok((char *)NULL, ":");
				hertz = strtod(token, NULL);
			}	
			break;
		}
	}
	//printf("CPU Mhz %9.6f, sysconf:%ld\n",hertz, sysconf(_SC_CLK_TCK));
	//filebench_log(LOG_VERBOSE, "Detected CPU Mhz as %9.6f\n", hertz);
	return hertz;	
}

#elif !defined(sun)
uint64_t
gethrtime() 
{
	struct tms tp;
	uint64_t hr;

	hr = times(&tp);
	
	return(hr);
}
#endif

static int urandomfd;

void
filebench_init()
{
	if ((urandomfd = open("/dev/urandom", O_RDONLY)) < 0) {
		filebench_log(LOG_ERROR, "open /dev/urandom failed: %s",
		    strerror(errno));
		filebench_shutdown(1);
	}
#if defined(USE_RDTSC) && (LINUX_PORT)
	mhz = parse_cpu_mhz();
	if(mhz <= 0) {
		filebench_log(LOG_ERROR, "Error getting CPU Mhz: %s",
		strerror(errno));
		filebench_shutdown(1);
	}
#endif /*USE_RDTSC */

}

uint64_t
filebench_randomno64(uint64_t max, uint64_t round)
{	
	uint64_t random;

	if (read(urandomfd, &random,
	    sizeof(uint64_t)) != sizeof(uint64_t)) {
		filebench_log(LOG_ERROR, "read /dev/urandom failed: %s",
		    strerror(errno));
		filebench_shutdown(1);
	}
	max -= round;
	random = random / (FILEBENCH_RANDMAX64 / max);
	if (round) {
		random = random / round;
		random *= round;
	}
	if (random > max)
		random = max;
	return(random);
}


uint32_t
filebench_randomno32(uint32_t max, uint32_t round)
{	
	uint32_t random;

	if (read(urandomfd, &random,
	    sizeof(uint32_t)) != sizeof(uint32_t)) {
		filebench_log(LOG_ERROR, "read /dev/urandom failed: %s",
		    strerror(errno));
		filebench_shutdown(1);
	}
	max -= round;
	random = random / (FILEBENCH_RANDMAX32 / max);
	if (round) {
		random = random / round;
		random *= round;
	}
	if (random > max)
		random = max;
	return(random);
}

extern int lex_lineno;

/*
 * Send a message to stdout
 */
void
filebench_log __V((int level, const char *fmt, ...))
{
	va_list args;
	hrtime_t now;
	char line[131072];
	char buf[131072];
	char path[MAXPATHLEN];
	char *s;


	if (level == LOG_FATAL)
		goto fatal;

	if ((level == LOG_LOG) && 
	    (filebench_shm->log_fd < 0)) {
		strcpy(path, filebench_shm->fscriptname);
		if ((s = strstr(path, ".f")))
			*s = 0;
		else
			strcpy(path, "filebench");

		strcat(path, ".csv");

		filebench_shm->log_fd = 
		    open(path, O_RDWR | O_CREAT | O_TRUNC, 0666);
	}
	
	if ((level == LOG_LOG) &&
	    (filebench_shm->log_fd < 0)) {
		sprintf(line, "Open logfile failed: %s", strerror(errno));
		level = LOG_ERROR;
	}

	if ((level == LOG_DUMP) && 
	    (*filebench_shm->dump_filename == 0))
		return;

	if ((level == LOG_DUMP) && 
	    (filebench_shm->dump_fd < 0)) {

		filebench_shm->dump_fd = 
		    open(filebench_shm->dump_filename,
			O_RDWR | O_CREAT | O_TRUNC, 0666);
	}
	
	if ((level == LOG_DUMP) &&
	    (filebench_shm->dump_fd < 0)) {
		sprintf(line, "Open logfile failed: %s", strerror(errno));
		level = LOG_ERROR;
	}
	
	/* Only log greater than debug setting */
	if ((level != LOG_DUMP) && (level != LOG_LOG) &&
	    (level > filebench_shm->debug_level))
		return;
	
	now = gethrtime();

fatal:
	
#ifdef __STDC__
	va_start(args, fmt);
#else
	char *fmt;
	va_start(args);
	fmt = va_arg(args, char *);
#endif
	
	vsprintf(line, fmt, args); 
	
	va_end(args);
	
	if (level == LOG_FATAL) {
		fprintf(stdout, "%s\n", line);
		return;
	}

	/* Serialize messages to log */
	ipc_mutex_lock(&filebench_shm->msg_lock);

	if (level == LOG_LOG) {
		if (filebench_shm->log_fd > 0) {
			sprintf(buf, "%s\n", line);
			write(filebench_shm->log_fd, buf, strlen(buf));
			fsync(filebench_shm->log_fd);
		}

	} else if (level == LOG_DUMP) {
		if (filebench_shm->dump_fd != -1) {
			sprintf(buf, "%s\n", line);
			write(filebench_shm->dump_fd, buf, strlen(buf));
			fsync(filebench_shm->dump_fd);
		}

	} else if (filebench_shm->debug_level > LOG_INFO) {
		fprintf(stdout, "%5ld: %4.3f: %s",
		    pid, (now - filebench_shm->epoch) / FSECS,
		    line);
		
	} else {
		fprintf(stdout, "%4.3f: %s", 
		    (now - filebench_shm->epoch) / FSECS,
		    line);
	}

	if (level == LOG_ERROR) {
		fprintf(stdout, " on line %d", lex_lineno);
	}
	
	if ((level != LOG_LOG) && (level != LOG_DUMP)) {
		fprintf(stdout, "\n");
		fflush(stdout);
	}

	ipc_mutex_unlock(&filebench_shm->msg_lock);
}

void
filebench_shutdown(int error) {
	filebench_log(LOG_DEBUG_IMPL, "Shutdown");
	unlink("/tmp/filebench_shm");
	if (filebench_shm->allrunning)
		procflow_shutdown();
	filebench_shm->f_abort = 1;
	ipc_ismdelete();
	exit(error);
}

/* Put the hostname in ${hostname} */
var_t *
host_var(var_t *var)
{
	char s[128];

	gethostname(s, 128);
	if (var->var_string)
		free(var->var_string);
	var->var_string = stralloc(s);
}

/* Put the date in ${date} */
var_t *
date_var(var_t *var)
{
	char s[128];
	time_t t = time(NULL);

#ifdef HAVE_CFTIME
	cftime(s, "%y%m%d%H" "%M", &t);
#else
	strftime(s, sizeof(s), "%y%m%d%H %M", &t);
#endif

	if (var->var_string)
		free(var->var_string);
	var->var_string = stralloc(s);

	return(var);
}

extern char *fscriptname;

/* Put the script name in ${script} */
var_t *
script_var(var_t *var)
{
	char *s;
	char *f = stralloc(fscriptname);

	/* Trim the .f suffix */
	for (s = f + strlen(f) - 1; 
	     s != f; s--) {
		if (*s == '.') {
			*s = 0;
			break;
		}
	}

	var->var_string = stralloc(basename(f));
	free(f);

	return(var);
}





