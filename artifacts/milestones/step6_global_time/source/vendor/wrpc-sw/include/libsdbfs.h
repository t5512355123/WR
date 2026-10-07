#ifndef __LIBSDBFS_H__
#define __LIBSDBFS_H__

/* The library can work in different environments, take care of them */
#ifdef __KERNEL__
#  include "libsdbfs-kernel.h"
#elif defined(__unix__)
#  include "libsdbfs-user.h"
#else
#  include "libsdbfs-freestanding.h"
#endif

#include <sdb.h> /* Please point your "-I" to some sensible place */

/*
 * Data structures: please note that the library itself doesn't use
 * malloc, so it's the caller who must deal with allocation/removal.
 * For this reason we can have no opaque structures, but some fields
 * are private
 */

struct sdbfs {

	/* Some fields are informative */
	struct storage_device *dev;
	unsigned long entrypoint;

	/* The following fields are library-private */

	/* The current file */
	struct sdb_device *currentp;
	struct sdb_device current_record;
	unsigned long f_len;
	unsigned long f_offset;		/* start of file */

	/* The following ones are directory-aware */
	unsigned long this;	/* current sdb record */
	int nleft;
};

/* Defined in sdbfs.c */
int sdbfs_open_id(struct sdbfs *fs, uint64_t vid, uint32_t did);
int sdbfs_close(struct sdbfs *fs);
struct sdb_device *sdbfs_scan(struct sdbfs *fs, int newscan);

int sdbfs_fread(struct sdbfs *fs, int offset, void *buf, int count);
int sdbfs_fwrite(struct sdbfs *fs, int offset, void *buf, int count);
int sdbfs_ferase(struct sdbfs *fs, int offset, int count);

#endif /* __LIBSDBFS_H__ */
