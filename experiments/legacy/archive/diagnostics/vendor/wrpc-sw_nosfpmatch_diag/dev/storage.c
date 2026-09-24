/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012, 2013 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <errno.h>
#include "wrc.h"
#include "storage.h"

#include "dev/endpoint.h"
#include "dev/syscon.h"
#include "sdb.h"

#include <libsdbfs.h>

#ifndef BOARD_USE_CUSTOM_SDBFS
static const uint32_t sdbfs_default_bin[] =
{
	#include "generated/sdbfs-default.h"
};
#else
	extern const uint32_t sdbfs_default_bin[];
#endif

struct storage_device wrc_storage_dev;
struct sdbfs wrc_sdbfs;

int storage_mount( struct storage_device *dev )
{
	uint32_t magic = 0;
	uint32_t addr;
	int i;

	/* Check if there is SDBFS in the memory */

	storage_dbg("mounting '%s' [%d bytes]\n", dev->name, dev->size );

	for (i = 0; dev->entry_points[i] >= 0; i++)
	{
		addr = dev->entry_points[i];
		if (addr >= dev->size)
			continue;

		storage_dbg("try entry point 0x%08x\n", addr);
		dev->rwops->read(dev->priv, addr, (void *)&magic, sizeof(magic) );
		if (magic == htonl (SDB_MAGIC))
			goto found;
	}
	storage_dbg("SDBFS not found.\n");

	return -ENODEV;

found:
	/* found? mount it! */
	storage_dbg("found SDBFS at 0x%x in device '%s'\n", addr, dev->name );
	wrc_sdbfs.dev = dev;
	wrc_sdbfs.entrypoint = addr;
	return 0;

}


static inline unsigned long SDB_ALIGN(unsigned long x, int blocksize)
{
	return (x + (blocksize - 1)) & ~(blocksize - 1);
}

int storage_sdbfs_erase( struct storage_device *dev, uint32_t addr, int force_base )
{
	int total_size = SDBFS_REC * dev->block_size;
	int count;
	uint32_t base_addr;

	if (force_base)
		base_addr = addr;
	else
		base_addr = dev->cfg_entry;

	for (count = 0; count < total_size; count += dev->block_size)
	{
		dev->rwops->erase(dev->priv, base_addr + count, dev->block_size );
	}

	return 0;
}

int storage_sdbfs_format( struct storage_device *dev, uint32_t addr, int force_base )
{
	struct sdb_device *sdbfs =
		 (struct sdb_device *) sdbfs_default_bin;
	struct sdb_interconnect *sdbfs_dir = (struct sdb_interconnect *)
		sdbfs_default_bin;
	struct sdb_device sdbfs_buf[SDBFS_REC];

	int i;
	int cur_adr, size;
	uint32_t base_addr;

	if (force_base)
		base_addr = addr;
	else
		base_addr = dev->cfg_entry;

	/* first file starts after the SDBFS description */
	cur_adr = base_addr + SDB_ALIGN(SDBFS_REC*sizeof(struct sdb_device),
					dev->block_size );

	/* scan through files */
	for (i = 1; i < SDBFS_REC; ++i) {
		/* relocate each file depending on base address and block size*/
		size = ntohll(sdbfs[i].sdb_component.addr_last) -
			ntohll(sdbfs[i].sdb_component.addr_first);
		sdbfs[i].sdb_component.addr_first = htonll((uint64_t) cur_adr);
		sdbfs[i].sdb_component.addr_last  =
					    htonll((uint64_t)(cur_adr + size));
		cur_adr = SDB_ALIGN(cur_adr + (size + 1), dev->block_size);
	}
	/* update the directory */
	sdbfs_dir->sdb_component.addr_first = htonll(base_addr);
	sdbfs_dir->sdb_component.addr_last  =
		sdbfs[SDBFS_REC-1].sdb_component.addr_last;

	for (i = 0; i < SDBFS_REC; ++i)	{
		char buf[20];
		buf[19] = 0;
		strncpy(buf, (char *)sdbfs[i].sdb_component.product.name, 18);
		pp_printf("filename: %s; first: %x; last: %x\n", buf,
			  (int)ntohll(sdbfs[i].sdb_component.addr_first),
			  (int)ntohll(sdbfs[i].sdb_component.addr_last));
	}


	pp_printf("Formatting SDBFS (base 0x%08x, size 0x%08x)...\n",
		  (unsigned int) base_addr,
		  (unsigned int) (SDBFS_REC * dev->block_size) );

	storage_sdbfs_erase(dev, addr, force_base);

	size = sizeof(struct sdb_device);

	for (i = 0; i < SDBFS_REC; ++i) {
		dev->rwops->write(dev->priv, base_addr + i*size, &sdbfs[i],
				size);
	}

	pp_printf("Verification...\n");
	dev->rwops->read(dev->priv, base_addr, sdbfs_buf,
			 SDBFS_REC * sizeof(struct sdb_device));
	if(memcmp(sdbfs, sdbfs_buf, SDBFS_REC * sizeof(struct sdb_device)))
		pp_printf("Error.\n");
	else
		pp_printf("OK.\n");

	return storage_mount( dev );
}


/*
 * A trivial dumper, just to show what's up in there
 */
void storage_sdbfs_list(void)
{
	struct sdbfs *fs = &wrc_sdbfs;
	struct sdb_device *d;
	int new = 1;

	pp_printf("sdbfs on %s\n", wrc_storage_dev.name);
	if (!fs->dev) {
		/* If no device was mounted, exit now.  */
		pp_printf("no SDBFS\n");
		return;
	}
	while ((d = sdbfs_scan(fs, new)) != NULL) {
		unsigned addr_first, addr_last;
		/* Hack: ensure the name is NUL terminated. */
		d->sdb_component.product.record_type = '\0';

		addr_first = ntohll(d->sdb_component.addr_first);
		addr_last = ntohll(d->sdb_component.addr_last);
		pp_printf("file 0x%08x @ %08x-%08x, name %19s\n",
			  (unsigned)(d->sdb_component.product.device_id),
			  addr_first, addr_last,
			  (char *)(d->sdb_component.product.name));
		new = 0;
	}
}
