/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012, 2013 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include "wrc.h"
#include "storage.h"

#include <sdb.h>

#include <libsdbfs.h>

/*
 * The init script area consist of 2-byte size field and a set of
 * shell commands separated with '\n' character.
 *
 * -------------------
 * | bytes used (2B) |
 * ------------------------------------------------
 * | shell commands separated with '\n'.....      |
 * |                                              |
 * |                                              |
 * ------------------------------------------------
 */

int storage_init_erase(void)
{
	int ret;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_INIT) < 0)
		return -1;
	ret = sdbfs_ferase(&wrc_sdbfs, 0, wrc_sdbfs.f_len);
	if (ret == wrc_sdbfs.f_len)
		ret = 1;
	sdbfs_close(&wrc_sdbfs);
	return ret == 1 ? 0 : -1;
}

/*
 * Appends a new shell command at the end of boot script
 */
int storage_init_add(const char *args[])
{
	int len, i;
	uint8_t separator = ' ';
	uint16_t used, readback;
	int ret = -1;
	uint8_t byte;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_INIT) < 0)
		return -1;

	/* check how many bytes we already have there */
	used = 0;
	while (sdbfs_fread(&wrc_sdbfs, sizeof(used)+used, &byte, 1) == 1) {
		if (byte == 0xff)
			break;
		used++;
	}

	if (used > 256 /* 0xffff or wrong */)
		used = 0;

	i = 1; /* args[0] is "add" */
	while (args[i] != NULL) {
		len = strlen(args[i]);
		if (sdbfs_fwrite(&wrc_sdbfs, sizeof(used) + used,
				 (void *)args[i], len) != len)
			goto out;
		used += len;
		if (args[i+1] != NULL)	/* next one is another word of the same command */
			separator = ' ';
		else			/* no more words, end command with '\n' */
			separator = '\n';
		if (sdbfs_fwrite(&wrc_sdbfs, sizeof(used) + used,
				&separator, sizeof(separator))
		    != sizeof(separator))
			goto out;
		++used;
		++i;
	}
	/* and finally update the size of the script */
	if (sdbfs_fwrite(&wrc_sdbfs, 0, &used, sizeof(used)) != sizeof(used))
		goto out;

	if (sdbfs_fread(&wrc_sdbfs, 0, &readback, sizeof(readback))
	    != sizeof(readback))
		goto out;

	ret = 0;
out:
	sdbfs_close(&wrc_sdbfs);
	return ret;
}

int storage_init_show(void)
{
	int ret = -1;
	uint16_t used;
	uint8_t byte;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_INIT) < 0)
		return -1;

	pp_printf("-- user-defined script --\n");
	used = 0;
	do {
		if (sdbfs_fread(&wrc_sdbfs, sizeof(used) + used, &byte, 1) != 1)
			goto out;
		if (byte != 0xff) {
			pp_printf("%c", byte);
			used++;
		}
	} while (byte != 0xff);

	if (used == 0)
		pp_printf("(empty)\n");
	ret = 0;
out:
	sdbfs_close(&wrc_sdbfs);
	return ret;
}

int storage_init_readcmd(uint8_t *buf, int bufsize, int next)
{
	int i = 0, ret = -1;
	uint16_t used;
	static uint16_t ptr;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_INIT) < 0)
		return -1;

	if (next == 0)
		ptr = sizeof(used);
	do {
		if (i > bufsize)
			goto out;
		if (sdbfs_fread(&wrc_sdbfs, (ptr++),
				&buf[i], sizeof(char)) != sizeof(char))
			goto out;
		if (buf[i] == 0xff)
			break;
	} while (buf[i++] != '\n');
	ret = i;
out:
	sdbfs_close(&wrc_sdbfs);
	return ret;
}

