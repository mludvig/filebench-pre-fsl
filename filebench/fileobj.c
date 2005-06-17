/*
 * Copyright 2005 Sun Microsystems, Inc.  All rights reserved.
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License.
 * See the file LICENSING in this distribution for details.
 */

#include <fcntl.h>
#include <pthread.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>

#ifdef HAVE_UTILITY_H
#include <utility.h>
#endif

#include "vars.h"
#include "filebench.h"
#include "fileobj.h"

void
fileobj_usage()
{
	fprintf(stderr,
	    "define file name=<name>,path=<pathname>,size=<size>\n");
	fprintf(stderr, "		        [,paralloc]\n");
	fprintf(stderr, "		        [,prealloc]\n");
	fprintf(stderr, "		        [,reuse]\n");
	fprintf(stderr, "\n");
}

int
fileobj_freemem(int fd, off64_t size)
{
	off64_t left;
	off64_t thismapsize;
	caddr_t addr;
	int ret = -1;

#define MMAP_SIZE (1024UL * 1024UL * 1024UL)		
	for (left = size; left > 0; left -= MMAP_SIZE) {
		thismapsize = MIN(MMAP_SIZE, left);
		addr = mmap64(0, thismapsize, PROT_READ|PROT_WRITE, 
		    MAP_SHARED, fd, size - left);
		ret += msync(addr, thismapsize, MS_INVALIDATE);
		munmap(addr, thismapsize);
	}

	return (ret);
}

int
fileobj_prealloc(fileobj_t *fileobj)
{
	off64_t seek;
	int fd;
	char *buf;
	int ret;
	struct stat64 sb;
	char name[MAXPATHLEN];

	if (*fileobj->fo_path == NULL) {
		filebench_log(LOG_ERROR, "File path not set");
		return(-1);
	}
	
	strcpy(name, *fileobj->fo_path);
	mkdir(name, 0777);
	strcat(name, "/");
	strcat(name, fileobj->fo_name);
	
	if ((fd = open64(name, O_RDWR)) < 0) {
		filebench_log(LOG_ERROR,
		    "Failed to pre-allocate file %s: %s",
		    name, strerror(errno));
		return(-1);	
	}

	if (integer_isset(fileobj->fo_reuse) &&
	    (fstat64(fd, &sb) == 0) && (sb.st_size ==
		(off64_t)*fileobj->fo_size)) {
		filebench_log(LOG_INFO,
		    "Re-using file %s", name);
		if (!integer_isset(fileobj->fo_cached))
			fileobj_freemem(fd, *fileobj->fo_size);
		close(fd);
		return(0);
	}
		
	if ((buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL) {
		close(fd);
		return(-1);
	}

	for (seek = 0; seek < (off64_t)*fileobj->fo_size;
		 seek += FILE_ALLOC_BLOCK) {
		ret = write(fd, buf, FILE_ALLOC_BLOCK);
		if (ret != FILE_ALLOC_BLOCK) {
			filebench_log(LOG_ERROR,
			    "Failed to pre-allocate file %s: %s",
			    name, strerror(errno));
			close(fd);
			return(-1);
		}
	}

	filebench_log(LOG_INFO,
	    "Pre-allocated file %s", name);

	fsync(fd);
	if (!integer_isset(fileobj->fo_cached))
		fileobj_freemem(fd, *fileobj->fo_size);
	close(fd);       
	return(0);
}

int
fileobj_createfile(fileobj_t *fileobj)
{
	int fd;
	struct stat64 sb;
	char name[MAXPATHLEN];

	if (*fileobj->fo_path == NULL) {
		filebench_log(LOG_ERROR, "File path not set");
		return(-1);
	}
	
	strcpy(name, *fileobj->fo_path);
	mkdir(name, 0777);
	strcat(name, "/");
	strcat(name, fileobj->fo_name);

	if (integer_isset(fileobj->fo_reuse) &&
	    (stat64(name, &sb) == 0)) {
		fd = open64(name, O_RDWR);
		fsync(fd);
		fileobj_freemem(fd, *fileobj->fo_size);
		close(fd);
		return(fd < 0);
	}
	
	filebench_log(LOG_DEBUG_IMPL, "Creating file %s", name);
	unlink(name);
	if ((fd = open64(name, O_RDWR | O_CREAT, 0666)) < 0) {
		filebench_log(LOG_ERROR,
		    "Failed to create file %s: %s",
		    name, strerror(errno));
		return(-1);	
	}
	fsync(fd);
	close(fd);

	return(fd < 0);
}

int
fileobj_init()
{
	fileobj_t *fileobj = filebench_shm->filelist;
	int ret = 0;
	int nthreads = 0;

	ipc_mutex_lock(&filebench_shm->fileobj_lock);

	filebench_log(LOG_INFO,
	    "Creating/pre-allocating files");

	while (fileobj) {

		/* Create files */
		if (*fileobj->fo_create)
			ret += fileobj_createfile(fileobj);

		/* Preallocate files */
		if (integer_isset(fileobj->fo_prealloc)) {

			if (!integer_isset(fileobj->fo_paralloc)) {
				ret += fileobj_prealloc(fileobj);
				fileobj = fileobj->fo_next;
				continue;
			}

			if (pthread_create(&fileobj->fo_tid, NULL, 
			    (void *(*)(void*))fileobj_prealloc, 
			    fileobj) != 0) {
				filebench_log(LOG_ERROR, 
				    "File prealloc thread create failed");
				filebench_shutdown(1);
			} else {
				nthreads++;
			}
		}

		fileobj = fileobj->fo_next;
	}

	/* Wait for allocations to finish */
	if (nthreads) {
		filebench_log(LOG_INFO, 
		    "Waiting for preallocation threads to complete...");
		fileobj = filebench_shm->filelist;
		while (fileobj) {
			ret += pthread_join(fileobj->fo_tid, NULL);
			fileobj = fileobj->fo_next;
		}
	}

	ipc_mutex_unlock(&filebench_shm->fileobj_lock);

	return(ret);
}

fileobj_t *
fileobj_define(char *name)
{
	fileobj_t *fileobj;

	if (name == NULL)
		return NULL;

	fileobj = (fileobj_t *)ipc_malloc(FILEBENCH_FILEOBJ);
	
	filebench_log(LOG_DEBUG_IMPL, "Defining file %s", name);

	ipc_mutex_lock(&filebench_shm->fileobj_lock);

	/* Add fileobj to global list */
	if (filebench_shm->filelist == NULL) {
		filebench_shm->filelist = fileobj;
		fileobj->fo_next = NULL;
	} else {
		fileobj->fo_next = filebench_shm->filelist;
		filebench_shm->filelist = fileobj;
	}

	ipc_mutex_unlock(&filebench_shm->fileobj_lock);

	strcpy(fileobj->fo_name, name);

	return(fileobj);
}

int
fileobj_open(fileobj_t *fileobj, int attrs)
{
	int open_attrs = 0;
	int fd;
	char name[MAXPATHLEN];

	if (*fileobj->fo_path == NULL) {
		filebench_log(LOG_ERROR, "File path not set");
		return(-1);
	}

	strcpy(name, *fileobj->fo_path);
	mkdir(name, 0777);
	strcat(name, "/");
	strcat(name, fileobj->fo_name);

	if (attrs & FLOW_ATTR_DSYNC) {
#ifdef sun
		open_attrs |= O_DSYNC;
#else
	        open_attrs |= O_FSYNC;
#endif
	}

	fd = open64(name, O_RDWR | open_attrs, 0666);
	filebench_log(LOG_DEBUG_SCRIPT, "open file %s flags %d = %d",
		*fileobj->fo_path, open_attrs, fd);

	if (fd < 0) {
		filebench_log(LOG_ERROR,
		    "Failed to open %s: %s",
		    name,
		    strerror(errno));
	}

#ifdef sun
	if (attrs & FLOW_ATTR_DIRECTIO)
		directio(fd, DIRECTIO_ON);
	else
		directio(fd, DIRECTIO_OFF);
#endif

	return(fd);
}

fileobj_t *
fileobj_find(char *name)
{
	fileobj_t *fileobj = filebench_shm->filelist;

	ipc_mutex_lock(&filebench_shm->fileobj_lock);

	while (fileobj) {

		if (strcmp(name, fileobj->fo_name) == 0) {
			ipc_mutex_unlock(&filebench_shm->fileobj_lock);
			return(fileobj);
		}
		fileobj = fileobj->fo_next;
	}
	ipc_mutex_unlock(&filebench_shm->fileobj_lock);

	return(NULL);
}

void
fileobj_iter(int (*cmd)(fileobj_t *fileobj, int first))
{
	fileobj_t *fileobj = filebench_shm->filelist;
	int count = 0;

	ipc_mutex_lock(&filebench_shm->fileobj_lock);

	while (fileobj) {
		cmd(fileobj, count == 0);
		fileobj = fileobj->fo_next;
		count++;
	}

	ipc_mutex_unlock(&filebench_shm->fileobj_lock);

	return;
}

int
fileobj_print(fileobj_t *fileobj, int first)
{
	if (first) {
		filebench_log(LOG_INFO, "%10s %32s %8s",
		    "File Name",
		    "Path Name",
		    "Size");
	}

	filebench_log(LOG_INFO, "%10s %32s %8ld",
	    fileobj->fo_name,
	    *fileobj->fo_path,
	    *fileobj->fo_size);
	return(0);
}
