/*
 * Copyright (C) 2012,2014 CERN (www.cern.ch)
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 *
 * This work is part of the White Rabbit project, a research effort led
 * by CERN, the European Institute for Nuclear Research.
 */

/* To avoid many #ifdef and associated mess, all headers are included there */
#include "libsdbfs.h"
#include "dev/bb_i2c.h"
#include "dev/i2c_eeprom.h"
#include "storage.h"

/*
 * To open by name or by ID we need to scan the tree. The scan
 * function is also exported in order for "sdb-ls" to use it
 */

static struct sdb_device *sdbfs_readentry(struct sdbfs *fs,
					  unsigned long offset)
{
	/*
	 * This function reads an entry from a known good offset. It
	 * returns the pointer to the entry, which may be stored in
	 * the fs structure itself. Only touches fs->current_record.
	 */
	struct sdb_device *res = &fs->current_record;
	fs->dev->rwops->read(fs->dev->priv, offset, res, sizeof(*res));
	return res;
}

/* Helper for scanning: we enter a new directory, and we must validate */
static struct sdb_device *scan_newdir(struct sdbfs *fs)
{
	struct sdb_device *dev;
	struct sdb_interconnect *intercon;

	/* The first entry must be an interconnect */
	dev = fs->currentp = sdbfs_readentry(fs, fs->this);
	if (dev->sdb_component.product.record_type != sdb_type_interconnect)
		return NULL;

	intercon = (typeof(intercon))dev;
	if (ntohl(intercon->sdb_magic) != SDB_MAGIC)
		return NULL;

	/* Followed by the files */
	fs->nleft = ntohs(intercon->sdb_records) - 1;
	fs->this += sizeof(*intercon);
	return dev;
}

struct sdb_device *sdbfs_scan(struct sdbfs *fs, int newscan)
{
	/*
	 * This returns a pointer to the next sdb record, or the first one.
	 * Subdirectories (bridges) are returned before their contents.
	 * It only uses internal fields.
	 */
	struct sdb_device *dev;

	if (newscan) {
		fs->this = fs->entrypoint;

		dev = scan_newdir(fs);
		if (!dev)
			return NULL; /* no entries at all */
	}
	else {
		if (fs->nleft == 0) {
			/* No more entries */
			return NULL;
		}

		/* so, read the next entry */
		dev = fs->currentp = sdbfs_readentry(fs, fs->this);
		fs->this += sizeof(*dev);
		fs->nleft--;
	}

	fs->f_offset = htonll(fs->currentp->sdb_component.addr_first);
	return dev;
}

int sdbfs_open_id(struct sdbfs *fs, uint64_t vid, uint32_t did)
{
	struct sdb_device *d;

	if (fs->dev == NULL) {
		/* No sdb found, so no file */
		return -ENOENT;
	}

	sdbfs_scan(fs, 1); /* new scan: get the interconnect and igore it */
	while ( (d = sdbfs_scan(fs, 0)) != NULL) {
		if (vid != d->sdb_component.product.vendor_id)
			continue;
		if (did != d->sdb_component.product.device_id)
			continue;
		fs->f_len = htonll(fs->currentp->sdb_component.addr_last)
			+ 1 - fs->f_offset;
		return 0;
	}
	return -ENOENT;
}


int sdbfs_fread(struct sdbfs *fs, int offset, void *buf, int count)
{
	int ret;

	if (!fs->currentp)
		return -ENOENT;
	if (offset + count > fs->f_len)
		count = fs->f_len - offset;
	ret = fs->dev->rwops->read(fs->dev->priv, fs->f_offset + offset, buf, count);
	return ret;
}

int sdbfs_fwrite(struct sdbfs *fs, int offset, void *buf, int count)
{
	int ret;

	if (!fs->currentp)
		return -ENOENT;
	if (offset + count > fs->f_len)
		count = fs->f_len - offset;
	ret = fs->dev->rwops->write(fs->dev->priv, fs->f_offset + offset, buf, count);
	return ret;
}

int sdbfs_ferase(struct sdbfs *fs, int offset, int count)
{
	int ret;

	if (!fs->currentp)
		return -ENOENT;
	if (offset + count > fs->f_len)
		count = fs->f_len - offset;
	ret = fs->dev->rwops->erase(fs->dev->priv, fs->f_offset + offset, count);
	return ret;
}

int sdbfs_close(struct sdbfs *fs)
{
	fs->currentp = NULL;
	return 0;
}
