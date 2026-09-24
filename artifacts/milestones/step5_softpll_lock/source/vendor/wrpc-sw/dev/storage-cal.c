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

#include "sdb.h"

#include <libsdbfs.h>

/*
 * Calibration File Functions
 */

static wrc_cal_data_t cal_data;

static int calc_checksum( wrc_cal_data_t* cal )
{
	int i;
	uint32_t cksum = 0;
	cksum += cal->magic;
	cksum += cal->param_count;
	for(i = 0; i < cal->param_count; i++)
	{
		cksum += cal->params[i].id;
		cksum += cal->params[i].value;
	}

	return cksum;
}

int storage_get_calibration_parameter(uint32_t id, uint32_t *valp )
{
	int i;

	for(i = 0; i < cal_data.param_count; i++)
	{
		if ( id == cal_data.params[i].id )
		{
			*valp = cal_data.params[i].value;
			return 0;
		}
	}

	return -1;
}

int storage_set_calibration_parameter(uint32_t id, uint32_t val )
{
	int i;

	for(i = 0; i < cal_data.param_count; i++)
	{
		if ( id == cal_data.params[i].id )
		{
			cal_data.params[i].value = val;
			return 0;
		}
	}

	if( cal_data.param_count >= CAL_MAX_PARAMS )
	{
		storage_dbg("can't save due to too many calibration parameters, please increase CAL_MAX_PARAMS!");
		return -1;
	}

	cal_data.params[cal_data.param_count].id = id;
	cal_data.params[cal_data.param_count].value = val;
	cal_data.param_count ++;

	return 0;
}

int storage_remove_calibration_parameter(uint32_t id )
{
	int i;
	for(i = 0; i < cal_data.param_count; i++)
	{
		if ( id == cal_data.params[i].id )
		{
			/* If i is the last index, at worst we overwrite it */
			cal_data.param_count--;
			cal_data.params[i] = cal_data.params[cal_data.param_count];
			return 0;
		}
	}

	return -1;
}

int storage_set_calibration_parameter_and_save(uint32_t id, uint32_t val )
{
	int res = storage_set_calibration_parameter(id, val);

	if (res != 0)
		return res;

	return storage_save_calibration();
}

wrc_cal_data_t* storage_get_calibration_data(void)
{
	return &cal_data;
}

static uint8_t calibration_loaded = 0;

int storage_is_calibration_loaded(void)
{
	return calibration_loaded;
}


int storage_load_calibration(void)
{
	int ret = 0;
	int i;
	/* cal data with network endianess, for read/write to flash */
	wrc_cal_data_t cal_data_ne;

	cal_data.param_count = 0;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_CALIB) < 0)
	{
		storage_dbg("%s: can't open cal file\n", __FUNCTION__);
		return -1;
	}

	if (sdbfs_fread(&wrc_sdbfs, 0, &cal_data_ne, sizeof(cal_data_ne))
		    != sizeof(cal_data_ne))
	{
		ret = -1;
		cal_data.param_count = 0;
		goto out_close;
	}

	cal_data = cal_data_ne;
	ntohl_mem((uint8_t *)&cal_data, sizeof(cal_data));

	if( cal_data.magic != CAL_FILE_MAGIC )
	{
		storage_dbg("%s: invalid magic\n", __FUNCTION__);
		cal_data.param_count = 0;
		ret = -1;
		goto out_close;
	}

	uint32_t cksum = calc_checksum( &cal_data );

	if( cal_data.checksum != cksum )
	{
		storage_dbg("%s: invalid checksum %x vs %x\n", __FUNCTION__, cal_data.checksum, cksum );
		cal_data.param_count = 0;
		ret = -1;
		goto out_close;
	}


	storage_dbg("Loaded %d calibration params, checksum = 0x%x\n", cal_data.param_count, cal_data.checksum );

	for(i = 0; i < cal_data.param_count; i++)
	{
		storage_dbg( " - param %c%c%c%c = %d\n",
			((cal_data.params[i].id) >> 24) & 0xff,
			((cal_data.params[i].id) >> 16) & 0xff,
			((cal_data.params[i].id) >> 8) & 0xff,
			((cal_data.params[i].id) >> 0) & 0xff,
			  cal_data.params[i].value );
	}

	if( !ret )
	{
		calibration_loaded = 1;
	}

out_close:
	sdbfs_close(&wrc_sdbfs);
	return ret;
}

int storage_save_calibration(void)
{
	int ret = 0;
	int i;
	/* cal data with network endianess, for read/write to flash */
	wrc_cal_data_t cal_data_ne;

	if (sdbfs_open_id(&wrc_sdbfs, SDB_VENDOR, SDB_DEV_CALIB) < 0)
	{
		storage_dbg("%s: can't open calibration file\n", __FUNCTION__);
		return -1;
	}

	cal_data.magic = CAL_FILE_MAGIC;
	cal_data.checksum = calc_checksum( &cal_data );
	cal_data_ne = cal_data;
	htonl_mem((uint8_t *)&cal_data_ne, sizeof(cal_data_ne));

	sdbfs_ferase(&wrc_sdbfs, 0, wrc_sdbfs.f_len);

	if (sdbfs_fwrite(&wrc_sdbfs, 0, &cal_data_ne, sizeof(cal_data_ne))
	    != sizeof(cal_data_ne))
			goto out_close;

	storage_dbg("Saved %d bytes of calibration data:\n",
		    sizeof(cal_data_ne));

	for(i = 0; i < cal_data.param_count; i++)
	{
		storage_dbg( " - param %c%c%c%c = %d\n",
			((cal_data.params[i].id) >> 24) & 0xff,
			((cal_data.params[i].id) >> 16) & 0xff,
			((cal_data.params[i].id) >> 8) & 0xff,
			((cal_data.params[i].id) >> 0) & 0xff,
			  cal_data.params[i].value );
	}


out_close:
	sdbfs_close(&wrc_sdbfs);
	return ret;
}
