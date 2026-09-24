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

/* MAC Address Storage */

int storage_get_persistent_mac(int portnum, uint8_t *mac)
{
	int ret = 0;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_MAC) < 0)
		ret =-1;
	else {
		ret = sdbfs_fread(&wrc_sdbfs, 0, mac, 6);
		sdbfs_close(&wrc_sdbfs);
        }

	if (ret < 0)
		storage_dbg("%s: SDB error\n", __func__);
	if (mac[0] == 0xff ||
	    (mac[0] | mac[1] | mac[2] | mac[3] | mac[4] | mac[5]) == 0) {
		storage_dbg("%s: SDB file is empty\n", __func__);
		ret = -1;
	}

	if (ret < 0) {
		storage_dbg("%s: failure\n", __func__);
		return -1;
	}
	return 0;
}

int storage_set_persistent_mac(int portnum, uint8_t *mac)
{
	int ret;

	ret = sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_MAC);
	if (ret >= 0) {
		sdbfs_ferase(&wrc_sdbfs, 0, wrc_sdbfs.f_len);
		ret = sdbfs_fwrite(&wrc_sdbfs, 0, mac, 6);
	}
	sdbfs_close(&wrc_sdbfs);

	if (ret < 0) {
		storage_dbg("%s: SDB error, can't save\n", __func__);
		return -1;
	}
	return 0;
}
