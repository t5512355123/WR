/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __SFP_H
#define __SFP_H

#include <stdint.h>
#include <libwr/sfp_lib.h>


#ifdef CONFIG_SFP_DOM
#define HAS_SFP_DOM 1
#else
#define HAS_SFP_DOM 0
#endif

#define SFP_DOM_UPDATE_TICK_INTERVAL 1000

#define WRC_G_SFP_VERSION 1

#define SFP_NOT_MATCHED 1
#define SFP_MATCHED 2

#define SFP_GET 0
#define SFP_ADD 1

#define SFP_PN_LEN 16
#define SFP_ID_SFF8472 0x03
#define SFP_ID_SFF8636_QSFP 0x0d
#define SFP_ID_SFF8636_QSFP28 0x11
#define SFP_QSFP_PAGE_SELECT 127
#define SFP_QSFP_SERIAL_ID_START 128
#define SFP_QSFP_SERIAL_ID_SIZE 96
#define SFP_QSFP_VENDOR_PN_OFFSET 40

struct s_sfpinfo {
	char pn[SFP_PN_LEN];
	int64_t alpha;
	int32_t dTx;
	int32_t dRx;
	uint8_t chksum;
} __attribute__ ((__packed__));

struct sfp_info {
	uint32_t version;
	struct s_sfpinfo sfp_params;
	int32_t sfp_in_db;
	struct shw_sfp_header *sfp_header;
	struct shw_sfp_dom *sfp_dom;
};

extern struct sfp_info sfp_info;

/* Match plugged SFP with a DB entry */
int sfp_match(int force);

/* Read-only live header diagnostic. The caller supplies storage for one
 * shw_sfp_header; this does not update the cached header or calibration. */
int sfp_read_header_diagnostic(uint8_t *header, uint32_t *ack_mask);
int sfp_read_eeprom_diagnostic(uint8_t start, uint8_t *buffer,
			       uint32_t size, uint32_t *ack_mask);

/* update dom data */
int sfp_dom_update(void);

#endif
