#include <linux/limits.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <libgen.h>

#include "private.h"

static char ertm_big_lock[] = "/run/libertm/big-ertm-lock";
static char ertm_big_lock_dir[] = "/run/libertm";

int ertm_open_lock_file(struct ertm_status *st)
{
	char *dir = ertm_big_lock_dir;
	char *filename = ertm_big_lock;
	int fd;

	/* create dir if not exists */
	if ((access(dir, F_OK) != 0) && (mkdir(dir, 0755) < 0))
		return -1;
	/* dir created, create lock file */
	if (access(filename, F_OK) != 0) {
		if ((fd = open(filename, O_CREAT, 0755)) < 0)
			return -1;
		else
			close(fd);
	}
	/* open lock file */
	if ((fd = open(filename, O_RDONLY)) < 0)
		return -1;
	st->lock = fd;

	return 0;
}

int ertm_mutex_acquire(struct ertm_status *st)
{
	return flock(st->lock, LOCK_EX);
}

int ertm_mutex_release(struct ertm_status *st)
{
	return flock(st->lock, LOCK_UN);
}

struct ertm_mutex_ops flock_ops = {
	.create	 = ertm_open_lock_file,
	.acquire = ertm_mutex_acquire,
	.release = ertm_mutex_release,
}, *ertm_flock_mutex = &flock_ops;

static int __attribute__((__unused__))
flock_main(int argc, char *argv[])
{
	int c;
	struct ertm_status st, *h = &st;

	if (ertm_open_lock_file(h) < 0) {
		perror("open_lock_file");
		return -1;
	}
	while ((c = getchar()) != EOF)
	    switch (c) {
	    case 'l':
		    printf("lock: ");
		    if (ertm_mutex_acquire(h) < 0) {
			    perror("failed, acq");
			    continue;
		    }
		    printf("locked!\n");
		    break;
	    case 'u':
		    printf("unlock: ");
		    if (ertm_mutex_release(h) < 0) {
			    perror("failed, release");
			    continue;
		    }
		    printf("unlocked!\n");
		    break;
	    case 'q':
		    return 0;
		    break;
	    default:
		    break;
	    }
	return 0;
}
