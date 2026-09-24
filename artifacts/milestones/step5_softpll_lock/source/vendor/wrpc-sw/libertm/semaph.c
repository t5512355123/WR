#include <linux/limits.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <libgen.h>
#include <semaphore.h>

#include "private.h"

static char ertm_big_semaphore[] = "/ertm-big-lock";

int ertm_create_semaphore(struct ertm_status *st)
{
	sem_t *sem;

	sem = sem_open(ertm_big_semaphore, O_CREAT, 0660, 1);
	if (sem == SEM_FAILED)
		return -1;
	st->semaphore = sem;

	return 0;
}

static int ertm_semaphore_value(struct ertm_status *st)
{
	int sval;

	sem_getvalue(st->semaphore, &sval);
	return sval;
}

int ertm_semaphore_acquire(struct ertm_status *st)
{
	return sem_wait(st->semaphore);
}

int ertm_semaphore_release(struct ertm_status *st)
{
	int sval;

	sem_getvalue(st->semaphore, &sval);
	if (sval > 0)
		return 0;
	return sem_post(st->semaphore);
}

struct ertm_mutex_ops semaphore_ops = {
	.create	= ertm_create_semaphore,
	.acquire = ertm_semaphore_acquire,
	.release = ertm_semaphore_release,
}, *ertm_semaphore_mutex = &semaphore_ops;

static int __attribute__((__unused__))
semaphore_main(int argc, char *argv[])
{
	int c;
	struct ertm_status st, *h = &st;

	if (ertm_create_semaphore(h) < 0) {
		perror("semaphore creation");
		return -1;
	}
	while ((c = getchar()) != EOF) {
	    printf("sem = %d\n", ertm_semaphore_value(h));
	    switch (c) {
	    case 'l':
		    printf("lock: ");
		    if (ertm_semaphore_acquire(h) < 0) {
			    perror("failed, acq");
			    continue;
		    }
		    printf("locked!\n");
		    break;
	    case 'u':
		    printf("unlock: ");
		    if (ertm_semaphore_release(h) < 0) {
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
	}
	return 0;
}

int main(int argc, char *argv[])
{
	return semaphore_main(argc, argv);
}
