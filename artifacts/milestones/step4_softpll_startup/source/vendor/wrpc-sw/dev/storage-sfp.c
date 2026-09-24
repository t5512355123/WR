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

#include "sdb.h"

#include <libsdbfs.h>

/*
 * The SFP section is placed somewhere inside EEPROM (W1 or I2C), using sdbfs.
 *
 * Initially we have a count of SFP records
 *
 * For each sfp we have
 *
 * - part number (16 bytes)
 * - alpha (8 bytes)
 * - deltaTx (4 bytes)
 * - delta Rx (4 bytes)
 * - checksum (1 byte)  (low order 8 bits of the sum of all bytes)
 *
 * the total is 33 bytes for each sfp (ugly, but we are byte-oriented anyways
 */


/* Erase SFB database in the memory */
int storage_sfpdb_erase(void)
{
	int ret;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_SFP) < 0)
		return -1;
	ret = sdbfs_ferase(&wrc_sdbfs, 0, wrc_sdbfs.f_len);
	if (ret == wrc_sdbfs.f_len)
		ret = 1;
	sdbfs_close(&wrc_sdbfs);
	return ret == 1 ? 0 : -1;
}

/* Dummy check if sfp information is correct by verifying it doesn't have
 * 0xff bytes in the part name. */
static int sfp_valid(struct s_sfpinfo *sfp)
{
	int i;

	for (i = 0; i < SFP_PN_LEN; ++i) {
		if (sfp->pn[i] == 0xff)
			return 0;
	}
	return 1;
}

static int sfp_entry(struct s_sfpinfo *sfp, int oper, int pos)
{
	static int sfpcount = 0;
	struct s_sfpinfo tempsfp;
	int ret = -1;
	int i;
	int chksum = 0;
	uint8_t *ptr;
	int sdb_offset;

	if (pos >= SFPS_MAX)
		return EE_RET_POSERR;	/* position outside the range */

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_SFP) < 0)
		return -1;

	/* Read how many SFPs are in the database, but only in the first
	 * call */
	if (!pos) {
		sfpcount = 0;
		sdb_offset = 1; /* sfpcount */
		while (sdbfs_fread(&wrc_sdbfs, sdb_offset, &tempsfp,
					sizeof(tempsfp)) == sizeof(tempsfp)) {
			if (!sfp_valid(&tempsfp))
				break;
			sfpcount++;
			sdb_offset = 1 /* sfpcount */ + sfpcount * sizeof(tempsfp);
		}
	}

	if ((oper == SFP_ADD) && (sfpcount == SFPS_MAX)) {
		/* no more space to add new SFPs */
		ret = EE_RET_DBFULL;
		goto out;
	}

	if (!pos && (oper == SFP_GET) && sfpcount == 0) {
		/* no SFPs in the database */
		ret = 0;
		goto out;
	}

	if (oper == SFP_GET) {
		sdb_offset = 1 /* sfpcount */ + pos * sizeof(*sfp);
		if (sdbfs_fread(&wrc_sdbfs, sdb_offset, sfp, sizeof(*sfp))
				!= sizeof(*sfp))
			goto out;

		ptr = (uint8_t *)sfp;
		/* read sizeof() - 1 because we don't include checksum */
		for (i = 0; i < sizeof(struct s_sfpinfo) - 1; ++i)
			chksum = chksum + *(ptr++);
		if ((chksum & 0xff) != sfp->chksum) {
			pp_printf("sfp: corrupted checksum\n");
			goto out;
		}
		sfp->alpha = ntohll(sfp->alpha);
		sfp->dTx = ntohl(sfp->dTx);
		sfp->dRx = ntohl(sfp->dRx);
	}
	if (oper == SFP_ADD) {
		/* Make a copy because changing endianess by htonl, change
		 * the data */
		memcpy(&tempsfp, sfp, sizeof(tempsfp));
		/* count checksum */
		ptr = (uint8_t *)&tempsfp;

		tempsfp.alpha = htonll(tempsfp.alpha);
		tempsfp.dTx = htonl(tempsfp.dTx);
		tempsfp.dRx = htonl(tempsfp.dRx);

		/* use sizeof() - 1 because we don't include checksum */
		for (i = 0; i < sizeof(struct s_sfpinfo) - 1; ++i)
			chksum = chksum + *(ptr++);
		tempsfp.chksum = chksum;
		/* add SFP at the end of DB */
		sdb_offset = 1 /* sfpcount */ + sfpcount * sizeof(*sfp);
		if (sdbfs_fwrite(&wrc_sdbfs, sdb_offset, &tempsfp, sizeof(*sfp))
				!= sizeof(tempsfp)) {
			goto out;
		}
		sfpcount++;
	}
	ret = sfpcount;
out:
	sdbfs_close(&wrc_sdbfs);
	return ret;
}

static int storage_update_sfp(struct s_sfpinfo *sfp)
{
	int sfpcount = 1;
	int temp;
	int i;
	struct s_sfpinfo sfp_db[SFPS_MAX];
	struct s_sfpinfo *dbsfp;

	/* copy entries from flash to the memory, update entry if matched */
	for (i = 0; i < sfpcount; ++i) {
		dbsfp = &sfp_db[i];
		sfpcount = sfp_entry(dbsfp, SFP_GET, i);
		if (sfpcount <= 0)
			return sfpcount;
		if (!strncmp(dbsfp->pn, sfp->pn, 16)) {
			/* update matched entry */
			dbsfp->dTx = sfp->dTx;
			dbsfp->dRx = sfp->dRx;
			dbsfp->alpha = sfp->alpha;
		}
	}

	/* erase entire database */
	if (storage_sfpdb_erase() == EE_RET_I2CERR) {
		pp_printf("Could not erase DB\n");
		return -1;
	}

	/* add all SFPs */
	for (i = 0; i < sfpcount; ++i) {
		dbsfp = &sfp_db[i];
		temp = sfp_entry(dbsfp, SFP_ADD, 0);
		if (temp < 0) {
			/* if error, return it */
			return temp;
		}
	}
	return i;
}

int storage_get_sfp(struct s_sfpinfo *sfp, int oper, int pos)
{
	struct s_sfpinfo tmp_sfp;

	if (oper == SFP_GET) {
		/* Get SFP entry */
		return sfp_entry(sfp, SFP_GET, pos);
	}

	/* storage_match_sfp replaces content of parameter, so do the copy
	 * first */
	tmp_sfp = *sfp;
	if (!storage_match_sfp(&tmp_sfp)) { /* add a new sfp entry */
		pp_printf("Adding new SFP entry\n");
		return sfp_entry(sfp, SFP_ADD, 0);
	}

	pp_printf("Update existing SFP entry\n");
	return storage_update_sfp(sfp);
}

int storage_match_sfp(struct s_sfpinfo *sfp)
{
	int sfpcount = 1;
	int i;
	struct s_sfpinfo dbsfp;

	for (i = 0; i < sfpcount; ++i) {
		sfpcount = sfp_entry(&dbsfp, SFP_GET, i);
		if (sfpcount <= 0)
			return sfpcount;
		if (!strncmp(dbsfp.pn, sfp->pn, 16)) {
			sfp->dTx = dbsfp.dTx;
			sfp->dRx = dbsfp.dRx;
			sfp->alpha = dbsfp.alpha;
			return 1;
		}
	}
	return 0;

}
