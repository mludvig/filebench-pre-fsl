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
#include <math.h>
#include <libgen.h>
#include <sys/mman.h>
#include "fileset.h"
#include "filebench.h"
#include <gsl/gsl_randist.h>


void
fileset_usage()
{
	fprintf(stderr, "define fileset name=<name>,path=<pathname>,entries=<number>\n");
	fprintf(stderr, "		        [,dirwidth=[width]\n");
	fprintf(stderr, "		        [,dirgamma=[100-10000] (Gamma * 1000)\n");
	fprintf(stderr, "		        [,sizegamma=[100-10000] (Gamma * 1000)\n");
	fprintf(stderr, "		        [,prealloc=[percent]]\n");
	fprintf(stderr, "		        [,reuse]\n");
	fprintf(stderr, "\n");
}

int
fileset_freemem(int fd, off64_t size)
{
	off64_t left;
	off64_t thismapsize;
	caddr_t addr;
	int ret;

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

char *
fileset_resolvepath(filesetentry_t *entry)
{
	filesetentry_t *e = entry;
	char path[MAXPATHLEN];
	char pathtmp[MAXPATHLEN];
	char *s;
	
	*path = 0;
	while (e->fse_parent) {
		strcpy(pathtmp, "/");
		strcat(pathtmp, e->fse_path);
		strcat(pathtmp, path);
		strcpy(path, pathtmp);
		e = e->fse_parent;
	}

	s = malloc(strlen(path) + 1);
	strcpy(s, path);
	return(s);
}

/* Recursive mkdir */
int
fileset_mkdir(char *path, int mode)
{
	char *p;
	struct stat64 sb;
	char *dirs[65536];
	int i = 0;

	p = strdup(path);

	while (p) {
		if (stat64(p, &sb) == 0)
			break;
		if (strlen(p) < 3)
			break;
		dirs[i] = strdup(p);
		dirname(p);
		i++;
	}

	for (;i >= 0; i--) {
		mkdir(dirs[i], 0755);
	}
	return(0);
}


int 
fileset_openfile(fileset_t *fileset,
    filesetentry_t *entry, int flag, int mode, int attrs)
{
	char path[MAXPATHLEN];
	char dir[MAXPATHLEN];
	char *pathtmp;
	struct stat64 sb;
	int fd;
	int open_attrs = 0;

	*path = 0;
	strcpy(path, *fileset->fs_path);
	strcat(path, "/");
	strcat(path, fileset->fs_name);
	pathtmp = fileset_resolvepath(entry);
	strcat(path, pathtmp);
	strcpy(dir, path);
	free(pathtmp);
	dirname(dir);

	/* If we are going to create a file, create the parent dirs */
	if ((flag & O_CREAT) && (stat64(dir, &sb) != 0)) {
		fileset_mkdir(dir, 0755);
	}

	if (flag & O_CREAT)
		entry->fse_flags |= FSE_EXISTS;

        if (attrs & FLOW_ATTR_DSYNC) {
#ifdef sun
                open_attrs |= O_DSYNC;
#else
                open_attrs |= O_FSYNC;
#endif
        }

	if ((fd = open64(path, flag | open_attrs, mode)) < 0) {
		filebench_log(LOG_ERROR,
		    "Failed to open file %s: %s",
		    path, strerror(errno));
		ipc_mutex_unlock(&entry->fse_lock);
		return(-1);
	}
	ipc_mutex_unlock(&entry->fse_lock);

#ifdef sun
        if (attrs & FLOW_ATTR_DIRECTIO)
                directio(fd, DIRECTIO_ON);
	else
                directio(fd, DIRECTIO_OFF);
#endif

	return(fd);
}


/* Pick a file or dir from the filelist */
filesetentry_t *
fileset_pick(fileset_t *fileset, int flags, int tid)
{
	filesetentry_t *entry = NULL;
	filesetentry_t *first = NULL;

	ipc_mutex_lock(&filebench_shm->fileset_lock);

	while (entry == NULL) {

		if ((flags & FILESET_PICKDIR) && (flags & FILESET_PICKRESET)) {
			entry = fileset->fs_dirlist;
			while (entry) {
				entry->fse_flags |= FSE_FREE;
				entry = entry->fse_dirnext;
			}
			fileset->fs_dirfree = fileset->fs_dirlist;
		}
		
		if (!(flags & FILESET_PICKDIR) && (flags & FILESET_PICKRESET)) {
			entry = fileset->fs_filelist;
			while (entry) {
				entry->fse_flags |= FSE_FREE;
				entry = entry->fse_filenext;
			}
			fileset->fs_filefree = fileset->fs_filelist;
		}
		
		if (flags & FILESET_PICKUNIQUE) {
			if (flags & FILESET_PICKDIR) {
				entry = fileset->fs_dirfree;
				if (entry == NULL)
					goto empty;
				fileset->fs_dirfree = entry->fse_dirnext;
			} else {
				entry = fileset->fs_filefree;
				if (entry == NULL)
					goto empty;
				fileset->fs_filefree = entry->fse_filenext;
			}
			entry->fse_flags &= ~FSE_FREE;
		} else {
			if (flags & FILESET_PICKDIR) {
				entry = fileset->fs_dirrotor;
				if (entry == NULL)
				fileset->fs_dirrotor = 
				    entry = fileset->fs_dirlist;
				fileset->fs_dirrotor = entry->fse_dirnext;
			} else {
				entry = fileset->fs_filerotor[tid];
				if (entry == NULL)
					fileset->fs_filerotor[tid] = 
					    entry = fileset->fs_filelist;
				fileset->fs_filerotor[tid] = entry->fse_filenext;
			}
		}

		if (first == entry)
			goto empty;

		if (first == NULL)
			first = entry;

		/* Return locked entry */
		ipc_mutex_lock(&entry->fse_lock);

		/* If we ask for an existing file, go round again */
		if ((flags & FILESET_PICKEXISTS) && !(entry->fse_flags & FSE_EXISTS)) {
			ipc_mutex_unlock(&entry->fse_lock);
			entry = NULL;
		}

		/* If we ask for not an existing file, go round again */
		if ((flags & FILESET_PICKNOEXIST) && (entry->fse_flags & FSE_EXISTS)) {
			ipc_mutex_unlock(&entry->fse_lock);
			entry = NULL;
		}
	}

	ipc_mutex_unlock(&filebench_shm->fileset_lock);
	filebench_log(LOG_DEBUG_SCRIPT, "Picked file %s", entry->fse_path);
	return(entry);

empty:
	ipc_mutex_unlock(&filebench_shm->fileset_lock);
	return(NULL);
}

int
fileset_create(fileset_t *fileset)
{
	filesetentry_t *entry;
	char path[MAXPATHLEN];
	char dir[MAXPATHLEN];
	char *pathtmp;
	off64_t seek;
	int fd;
	char *buf;
	int ret;
	off64_t wsize;
	struct stat64 sb;
	char cmd[MAXPATHLEN];
	int pickflags = FILESET_PICKUNIQUE | FILESET_PICKRESET;
	hrtime_t start = gethrtime();
	off64_t left;
	off64_t thismapsize;
	caddr_t addr;
	int preallocated = 0;
	int randno;
	
	if ((buf = (char *)malloc(FILE_ALLOC_BLOCK)) == NULL) {
		return(-1);
	}

	if (*fileset->fs_path == NULL) {
		filebench_log(LOG_ERROR, "Fileset path not set");
		return(-1);
	}

	/* XXX Add check to see if there is enough space */

	/* Remove existing */
	strcpy(path, *fileset->fs_path);
	strcat(path, "/");
	strcat(path, fileset->fs_name);
	if ((stat64(path, &sb) == 0) && (strlen(path) > 3) &&
	    (strlen(*fileset->fs_path) > 2) && 
		(!integer_isset(fileset->fs_reuse))) {
		sprintf(cmd, "rm -rf %s", path);
		system(cmd);
		filebench_log(LOG_VERBOSE,
		    "Removed any existing fileset %s in %d seconds",
		    fileset->fs_name,
		    ((gethrtime() - start) / 1000000000) + 1);
	}
	mkdir(path, 0755);

	start = gethrtime();

	filebench_log(LOG_VERBOSE, "Creating fileset %s...",
	    fileset->fs_name);

	while (entry = fileset_pick(fileset, pickflags, 0)) {
		
		pickflags = FILESET_PICKUNIQUE;

		entry->fse_flags &= ~FSE_EXISTS;

		if (!integer_isset(fileset->fs_prealloc)) {
			ipc_mutex_unlock(&entry->fse_lock);
			continue;
		}

		*path = 0;
		strcpy(path, *fileset->fs_path);
		strcat(path, "/");
		strcat(path, fileset->fs_name);
		pathtmp = fileset_resolvepath(entry);
		strcat(path, pathtmp);
		strcpy(dir, path);
		free(pathtmp);

		dirname(dir);

		if (stat64(dir, &sb) != 0) {
			fileset_mkdir(dir, 0755);
		}

		randno = ((RAND_MAX * (100 - *(fileset->fs_preallocpercent)))
		    / 100);

		if (rand() < randno) {
			ipc_mutex_unlock(&entry->fse_lock);
			continue;
		}

		preallocated++;

		filebench_log(LOG_DEBUG_IMPL, "Populated %s", entry->fse_path);


		if (integer_isset(fileset->fs_reuse) &&
		    (stat64(path, &sb) == 0) && (sb.st_size ==
			(off64_t)entry->fse_size)) {

			filebench_log(LOG_INFO,
			    "Re-using file %s", path);

			if (!integer_isset(fileset->fs_cached)) {
				fileset_freemem(fd, entry->fse_size);
			}

			entry->fse_flags |= FSE_EXISTS;
			close(fd);
			ipc_mutex_unlock(&entry->fse_lock);
			continue;
		}
		
		if ((fd = open64(path, O_RDWR | O_CREAT, 0644)) < 0) {
			filebench_log(LOG_ERROR,
		    "Failed to pre-allocate file %s: %s",
		    path, strerror(errno));
			
			return(-1);	
		}
		
		entry->fse_flags |= FSE_EXISTS;

		wsize = MIN(entry->fse_size, FILE_ALLOC_BLOCK);
		
		for (seek = 0; seek < entry->fse_size;
		     seek += FILE_ALLOC_BLOCK) {
			ret = write(fd, buf, wsize);
			if (ret != wsize) {
				filebench_log(LOG_ERROR,
				    "Failed to pre-allocate file %s: %s",
				    path, strerror(errno));
				close(fd);
				return(-1);
			}
		}

		if (!integer_isset(fileset->fs_cached)) {
			fileset_freemem(fd, entry->fse_size);
		}

		close(fd);
		ipc_mutex_unlock(&entry->fse_lock);

		filebench_log(LOG_DEBUG_IMPL,
		    "Pre-allocated file %s size %lld", path, entry->fse_size);
	}
	filebench_log(LOG_VERBOSE,
	    "Preallocated %d of %lld of fileset %s in %d seconds",
	    preallocated,
	    *(fileset->fs_entries),
	    fileset->fs_name,
	    ((gethrtime() - start) / 1000000000) + 1);

	free(buf);
	return(0);
}

/* Add entry to filelist, no lock needed since single threaded */
int
fileset_insfilelist(fileset_t *fileset, filesetentry_t *entry)
{
	if (fileset->fs_filelist == NULL) {
		fileset->fs_filelist = entry;
		entry->fse_filenext = NULL;
	} else {
		entry->fse_filenext = fileset->fs_filelist;
		fileset->fs_filelist = entry;
	}
}

/* Add entry to dirlist, no lock needed since single threaded */
int
fileset_insdirlist(fileset_t *fileset, filesetentry_t *entry)
{
	if (fileset->fs_dirlist == NULL) {
		fileset->fs_dirlist = entry;
		entry->fse_dirnext = NULL;
	} else {
		entry->fse_dirnext = fileset->fs_dirlist;
		fileset->fs_dirlist = entry;
	}
}

int
fileset_populate_file(fileset_t *fileset, filesetentry_t *parent, int serial)
{
	char tmpname[16];
	char *path;
	filesetentry_t *entry;
	int ransize;
 	double drand;
	double gamma;

	entry = (filesetentry_t *)ipc_malloc(FILEBENCH_FILESETENTRY);
	pthread_mutex_init(&entry->fse_lock, ipc_mutexattr());
	entry->fse_parent = parent;
	entry->fse_fileset = fileset;
	entry->fse_flags |= FSE_FREE;
	fileset_insfilelist(fileset, entry);
	
	sprintf(tmpname, "%08d", serial);
	entry->fse_path = (char *)ipc_pathalloc(tmpname);
	
	gamma = *(fileset->fs_sizegamma) / 1000.0;

	if (gamma > 0) {
		drand = gsl_ran_gamma(fileset->fs_rand, gamma,
		    fileset->fs_meansize / gamma);
		entry->fse_size = drand;
	} else
		entry->fse_size = fileset->fs_meansize;

	fileset->fs_bytes += entry->fse_size;

	fileset->fs_realfiles++;
}

int
fileset_populate_subdir(fileset_t *fileset, filesetentry_t *parent, int serial, int depth)
{
	int randepth;
 	double drand;
	int ranwidth;
	double gamma;
	int i;
	int isleaf = 0;
	char tmpname[16];
	filesetentry_t *entry;
	
	depth += 1;

	/* Create dir node */
	entry = (filesetentry_t *)ipc_malloc(FILEBENCH_FILESETENTRY);
	pthread_mutex_init(&entry->fse_lock, ipc_mutexattr());

	sprintf(tmpname, "%08d", serial);
	entry->fse_path = (char *)ipc_pathalloc(tmpname);
	entry->fse_parent = parent;
	entry->fse_flags |= FSE_DIR | FSE_FREE;
	fileset_insdirlist(fileset, entry);

	gamma = *(fileset->fs_dirgamma) / 1000.0;
	if (gamma > 0) {
		drand = gsl_ran_gamma(fileset->fs_rand, gamma,
	    	fileset->fs_meandepth / gamma);
		randepth = drand;
	} else
		randepth = fileset->fs_meandepth;

	gamma = *(fileset->fs_sizegamma) / 1000.0;

	if (gamma > 0) {
		drand = gsl_ran_gamma(fileset->fs_rand, gamma,
		    fileset->fs_meanwidth / gamma);
		ranwidth = drand;
	} else
		ranwidth = fileset->fs_meanwidth;

	if (randepth == 0)
		randepth = 1;
	if (ranwidth == 0)
		ranwidth = 1;
	if (depth >= randepth)
		isleaf = 1;

	/*
	 * Create directory of random width according to distribution, or
	 * if root directory, continue until #files required
	 */
	for (i = 1;
	     ((parent == NULL) || (i < ranwidth + 1)) &&
		 (fileset->fs_realfiles < *(fileset->fs_entries)); i++) {
		if (parent && isleaf) {
			fileset_populate_file(fileset, entry, i);
		} else {
			fileset_populate_subdir(fileset, entry, i, depth);
		}
	}
	return(0);
}

int
fileset_populate(fileset_t *fileset)
{
	int i;
	filesetentry_t *root;
	int nfiles;
	int ndirs;
	int nleafdirs;
	double meandepth;
	int meandirwidth = *(fileset->fs_dirwidth);

	/* Skip if already populated */
	if (fileset->fs_bytes > 0)
		goto exists;

	/*
	 * Input params are:
	 *       # of files
	 *       ave # of files per dir
	 *       max size of dir
	 *       # ave size of file
	 *       max size of file
	 */
	gsl_rng_env_setup();
	fileset->fs_rantype = gsl_rng_default;
	fileset->fs_rand = gsl_rng_alloc(fileset->fs_rantype);

	nfiles = *(fileset->fs_entries);
	fileset->fs_meandepth = log(nfiles) / log(meandirwidth);
	fileset->fs_meanwidth = meandirwidth;
	fileset->fs_meansize = *(fileset->fs_size);

	fileset_populate_subdir(fileset, NULL, 1, 0);

exists:
	filebench_log(LOG_VERBOSE, "Fileset %s: %lld files, "
	    "avg dir = %.1lf, avg depth = %.1lf, mbytes=%lld",
	    fileset->fs_name,
	    *(fileset->fs_entries),
	    fileset->fs_meanwidth,
	    fileset->fs_meandepth,
	    fileset->fs_bytes / 1024UL / 1024UL);

	return(0);
}

fileset_t *
fileset_define(char *name)
{
	fileset_t *fileset;

	if (name == NULL)
		return NULL;

	fileset = (fileset_t *)ipc_malloc(FILEBENCH_FILESET);
	
	filebench_log(LOG_DEBUG_IMPL, "Defining file %s", name);

	ipc_mutex_lock(&filebench_shm->fileset_lock);

	fileset->fs_dirgamma = integer_alloc(1500);
	fileset->fs_sizegamma = integer_alloc(1500);

	/* Add fileset to global list */
	if (filebench_shm->filesetlist == NULL) {
		filebench_shm->filesetlist = fileset;
		fileset->fs_next = NULL;
	} else {
		fileset->fs_next = filebench_shm->filesetlist;
		filebench_shm->filesetlist = fileset;
	}

	ipc_mutex_unlock(&filebench_shm->fileset_lock);

	strcpy(fileset->fs_name, name);

	return(fileset);
}

int
fileset_initset(fileset_t *fileset)
{
}


int
fileset_createset(fileset_t *fileset)
{
	fileset_t *list;
	int ret = 0;

	if (fileset && integer_isset(fileset->fs_prealloc)) {
		fileset_populate(fileset);
		fileset_create(fileset);
		return(0);
	}

	list = filebench_shm->filesetlist;
	while (list) {
		ret += fileset_populate(list);
		ret += fileset_create(list);
		list = list->fs_next;
	}
		
	return(ret);
}

fileset_t *
fileset_find(char *name)
{
	fileset_t *fileset = filebench_shm->filesetlist;

	ipc_mutex_lock(&filebench_shm->fileset_lock);

	while (fileset) {

		if (strcmp(name, fileset->fs_name) == 0) {
			ipc_mutex_unlock(&filebench_shm->fileset_lock);
			return(fileset);
		}
		fileset = fileset->fs_next;
	}
	ipc_mutex_unlock(&filebench_shm->fileset_lock);

	return(NULL);
}
