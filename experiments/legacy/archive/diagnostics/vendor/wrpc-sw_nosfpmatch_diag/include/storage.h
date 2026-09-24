/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 - 2015 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __STORAGE_H
#define __STORAGE_H

#include "sfp.h"
#include "dev/i2c_eeprom.h"
#include "dev/w1.h"

// calibration parameter definitions. Board-specific.
// fixme: move MAX_CAL_PARAMS to BSP
#define CAL_MAX_PARAMS 12
#define CAL_FILE_MAGIC 0xcafebabe

#define ASCII_TO_U32(a, b, c, d) ((((uint32_t)(a)&0xff) << 24) |     \
				 (((uint32_t)(b)&0xff) << 16) | \
				 (((uint32_t)(c)&0xff) << 8) |  \
				 (((uint32_t)(d)&0xff) << 0))

#define CAL_PARAM_T24P ASCII_TO_U32('t', '2', '4', 'p')
#define CAL_PARAM_PHY_TARGET_TX_PHASE ASCII_TO_U32('l', 'p', 't', 'p')
#define CAL_PARAM_DDS_LO_IOUPDATE_DELAY_PS ASCII_TO_U32('e', '1', '4', '0')	
#define CAL_PARAM_DDS_REF_IOUPDATE_DELAY_PS ASCII_TO_U32('e', '1', '4', '1')
#define CAL_PARAM_CLKA_SYNC_DELAY_PS ASCII_TO_U32('e', '1', '4', '2')
#define CAL_PARAM_CLKB_SYNC_DELAY_PS ASCII_TO_U32('e', '1', '4', '3')
#define CAL_PARAM_CALIBRATION_DATE ASCII_TO_U32('d','a','t','e')
#define CAL_PARAM_FPGA_DNA_0 ASCII_TO_U32('d','n','a','0')
#define CAL_PARAM_COMMIT_SHA_0 ASCII_TO_U32('s','h','a','0')

#define SFP_SECTION_PATTERN 0xdeadbeef

#define SFPS_MAX 4


#define EE_RET_I2CERR -1
#define EE_RET_DBFULL -2
#define EE_RET_CORRPT -3
#define EE_RET_POSERR -4

/* Well-knonw SDB files.  */
#define SDB_VENDOR	htonll(0x46696c6544617461LL) /* "FileData" */
#define SDB_DEV_INIT	htonl(0x77722d69) /* wr-i (nit) */
#define SDB_DEV_MAC	htonl(0x6d61632d) /* mac- (address) */
#define SDB_DEV_SFP	htonl(0x7366702d) /* sfp- (database) */
#define SDB_DEV_CALIB	htonl(0x63616c69) /* cali (bration) */


struct storage_device;

struct wrc_cal_param 
{
	uint32_t id;
	uint32_t value;
};

typedef struct
{
	uint32_t magic;
	uint32_t param_count;
	uint32_t checksum;
	struct wrc_cal_param params[CAL_MAX_PARAMS];
} __attribute__ ((__packed__)) wrc_cal_data_t;

struct spi_flash_device;

struct storage_rwops
{
	int (*read)( struct storage_device*, int offset, void *buf, int count );
	int (*write)( struct storage_device*, int offset, void *buf, int count );
	int (*erase)( struct storage_device*, int offset, int count );
};

struct storage_device
{
	const char *name;
	void *priv;
	uint32_t block_size;
	uint32_t size;
	uint32_t cfg_entry;
	const int32_t *entry_points;
	const struct storage_rwops *rwops;
};

extern struct storage_device wrc_storage_dev;
extern struct sdbfs wrc_sdbfs;

void storage_spiflash_create(struct storage_device *dev, struct spi_flash_device *flash);
void storage_i2ceeprom_create(struct storage_device *dev, struct i2c_eeprom_device *eeprom);

/* Return 0 if OK, < 0 on error (no eeprom device).  */
int storage_w1eeprom_create(struct storage_device *dev, struct w1_bus *bus);

void storage_init( struct i2c_bus *bus, int i2c_addr);

int storage_sfpdb_erase(void);
int storage_match_sfp(struct s_sfpinfo *sfp);
int storage_get_sfp(struct s_sfpinfo *sfp, int add, int pos);

int storage_init_erase(void);
int storage_init_add(const char *args[]);
int storage_init_show(void);
int storage_init_readcmd(uint8_t *buf, int bufsize, int next);
int storage_sdbfs_erase( struct storage_device *dev, uint32_t addr, int force_base );
int storage_sdbfs_format( struct storage_device *dev, uint32_t addr, int force_base );
void storage_sdbfs_list(void);

int storage_is_calibration_loaded(void);
int storage_get_calibration_parameter(uint32_t id, uint32_t *valp );
int storage_set_calibration_parameter(uint32_t id, uint32_t val );
int storage_remove_calibration_parameter(uint32_t id );
int storage_set_calibration_parameter_and_save(uint32_t id, uint32_t val );
wrc_cal_data_t* storage_get_calibration_data(void);
int storage_load_calibration(void);
int storage_save_calibration(void);

int storage_read_hdl_cfg(void);
int storage_mount( struct storage_device *dev );
int storage_get_persistent_mac(int portnum, uint8_t *mac);
int storage_set_persistent_mac(int portnum, uint8_t *mac);
#endif
