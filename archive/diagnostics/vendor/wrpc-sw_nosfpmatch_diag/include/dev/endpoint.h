/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __ENDPOINT_H
#define __ENDPOINT_H

#include <stdint.h>
#include "hw/rawmem.h"

typedef enum {
	AND = 0,
	NAND = 4,
	OR = 1,
	NOR = 5,
	XOR = 2,
	XNOR = 6,
	MOV = 3,
	NOT = 7
} pfilter_op_t;

#define EP_DEV_MAC_ADDR_SET ( 1<<0 )
#define EP_DEV_AUTONEG_ENABLED ( 1<<1 )

struct wr_endpoint_device
{
	uint8_t mac_addr[6];
	uint8_t flags;
	void *base;
};

static inline void ep_write( struct wr_endpoint_device* dev, uint32_t addr, uint32_t data)
{
	writel( data, addr + dev->base );
}

static inline uint32_t ep_read( struct wr_endpoint_device* dev, uint32_t addr)
{
	return readl( addr + dev->base );
}

void ep_init(struct wr_endpoint_device* dev, void *base_addr);
void ep_set_mac_addr(struct wr_endpoint_device* dev, uint8_t *addr);
int ep_is_mac_addr_set(struct wr_endpoint_device* dev);
int ep_enable(struct wr_endpoint_device* dev, int enabled, int autoneg);
int ep_link_up(struct wr_endpoint_device* dev, uint16_t * lpa);
int ep_get_bitslide(struct wr_endpoint_device* dev);
int ep_get_deltas(struct wr_endpoint_device *dev, int *delta_tx, int *delta_rx);
int ep_timestamper_cal_pulse(struct wr_endpoint_device* dev);
int ep_sfp_enable(struct wr_endpoint_device* dev, int ena);

uint16_t ep_pcs_read(struct wr_endpoint_device* dev, int location);
void ep_pcs_write(struct wr_endpoint_device* dev, int location, int value);
void ep_reset_phy(struct wr_endpoint_device* dev);

void ep_pfilter_init_default(struct wr_endpoint_device* dev);

#endif
