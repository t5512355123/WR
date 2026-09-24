/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include <string.h>
#include "wrc.h"

#include "board.h"
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include "dev/minic.h"
#include "storage.h"
#include "shell.h"
#include "ppsi/lib.h"

#include "hw/endpoint_regs.h"
#include "hw/ep_mdio_regs.h"

#include <wrc_global.h>

/* Length of a single bit on the gigabit serial link in picoseconds. Used for calculating deltaRx/deltaTx
   from the serdes bitslip value */
#define PICOS_PER_SERIAL_BIT 800

/* functions for accessing PCS (MDIO) registers */
uint16_t ep_pcs_read(struct wr_endpoint_device *dev, int location)
{
	ep_write(dev, EP_REG_MDIO_ASR, ((location >> 10) & 0xff) << EP_MDIO_ASR_PHYAD_SHIFT);
	ep_write(dev, EP_REG_MDIO_CR,
		(((location >> 2) & 0xff) << EP_MDIO_CR_ADDR_SHIFT) );

	while (( ep_read(dev, EP_REG_MDIO_ASR) & EP_MDIO_ASR_READY) == 0) ;
	uint32_t rv = EP_MDIO_ASR_RDATA_R(ep_read(dev, EP_REG_MDIO_ASR)) & 0xffff;

	return rv;
}

void ep_pcs_write(struct wr_endpoint_device *dev, int location, int value)
{
	ep_write(dev, EP_REG_MDIO_ASR, ((location >> 10) & 0xff) << EP_MDIO_ASR_PHYAD_SHIFT);

	ep_write(dev, EP_REG_MDIO_CR,
		(((location >> 2) & 0xff) << EP_MDIO_CR_ADDR_SHIFT)
	    | EP_MDIO_CR_DATA_W(value)
	    | EP_MDIO_CR_RW );

	while (( ep_read(dev, EP_REG_MDIO_ASR) & EP_MDIO_ASR_READY) == 0) ;
}

void ep_set_mac_addr(struct wr_endpoint_device* dev, uint8_t *addr)
{
	char buf[20] __attribute__((unused));
	memcpy(dev->mac_addr, addr, 6);

	mac_dbg("endpoint @ 0x%x: set MAC to %s\n", dev->base,
			format_mac(buf, dev->mac_addr));

	ep_write(dev, EP_REG_MACL, ((uint32_t) dev->mac_addr[2] << 24)
	    | ((uint32_t) dev->mac_addr[3] << 16)
	    | ((uint32_t) dev->mac_addr[4] << 8)
	    | ((uint32_t) dev->mac_addr[5]) );

	ep_write(dev, EP_REG_MACH, ((uint32_t) dev->mac_addr[0] << 8)
	    | ((uint32_t) dev->mac_addr[1]) );

	dev->flags |= EP_DEV_MAC_ADDR_SET;

	/* save the MAC addr for wrpc-dump */
	memcpy(wrc_global_link.mac_addr, dev->mac_addr, ETH_ALEN);
}

int ep_is_mac_addr_set(struct wr_endpoint_device* dev)
{
	return (dev->flags & EP_DEV_MAC_ADDR_SET) ? 1 : 0;
}

/* Initializes the endpoint and sets its local MAC address */
void ep_init(struct wr_endpoint_device* dev, void *base_addr)
{
	dev->base = base_addr;
	dev->flags = 0;

	ep_sfp_enable(dev, 1);

	ep_write(dev, EP_REG_ECR, 0);		/* disable Endpoint */
	ep_write(dev, EP_REG_VCR0, EP_VCR0_QMODE_W(3));	/* disable VLAN unit - not used by WRPC */
	ep_write(dev, EP_REG_RFCR, EP_RFCR_MRU_W(1518));	/* Set the max RX packet size */
	ep_write(dev, EP_REG_TSCR, EP_TSCR_EN_TXTS | EP_TSCR_EN_RXTS);	/* Enable timestamping */
}

void ep_reset_phy(struct wr_endpoint_device* dev)
{
	uint32_t mcr;
/* Reset the GTP Transceiver - it's important to do the GTP phase alignment every time
   we start up the software, otherwise the calibration RX/TX deltas may not be correct */
	ep_pcs_write(dev, EP_MDIO_MCR, EP_MDIO_MCR_PDOWN);	/* reset the PHY */
	
	/* Don't have delay in simulations */
	#ifndef CONFIG_WR_NODE_SIM 
		phy_dbg("Running long PHY reset...\n");
		timer_delay_ms(1000);
		phy_dbg("PHY reset complete\n");		 
	#endif
	
	ep_pcs_write(dev, EP_MDIO_MCR, EP_MDIO_MCR_RESET);	/* reset the PHY */
	ep_pcs_write(dev, EP_MDIO_MCR, 0);	/* reset the PHY */

/* Don't advertise anything - we don't want flow control */
	ep_pcs_write(dev, EP_MDIO_ADVERTISE, 0);

	mcr = EP_MDIO_MCR_SPEED1000 | EP_MDIO_MCR_FULLDPLX;
	if (dev->flags & EP_DEV_AUTONEG_ENABLED)
		mcr |= EP_MDIO_MCR_ANENABLE | EP_MDIO_MCR_ANRESTART;

	ep_pcs_write(dev, EP_MDIO_MCR, mcr);
	ep_pcs_write(dev, EP_MDIO_WR_SPEC, 0);
}

/* Enables/disables transmission and reception. When autoneg is set to 1,
   starts up 802.3 autonegotiation process */
int ep_enable(struct wr_endpoint_device* dev, int enabled, int autoneg)
{
	if (!enabled) {
		ep_write(dev, EP_REG_ECR, 0);
		return 0;
	}

/* Disable the endpoint */
	ep_write(dev, EP_REG_ECR, 0);

	if (!IS_WR_NODE_SIM)
		mac_dbg("MAC/Endpoint ID: %x\n", ep_read(dev, EP_REG_IDCODE) );

/* Load default packet classifier rules - see ep_pfilter.c for details */
	ep_pfilter_init_default( dev );

/* Enable TX/RX paths, reset RMON counters */
	ep_write(dev, EP_REG_ECR, EP_ECR_TX_EN | EP_ECR_RX_EN | EP_ECR_RST_CNT );

	if(autoneg)
		dev->flags |= EP_DEV_AUTONEG_ENABLED;
	else
		dev->flags &= ~EP_DEV_AUTONEG_ENABLED;

	ep_reset_phy(dev);

	return 0;
}

/* Checks the link status. If the link is up, returns non-zero
   and stores the Link Partner Ability (LPA) autonegotiation register at *lpa */
int ep_link_up(struct wr_endpoint_device* dev, uint16_t * lpa)
{
	uint16_t flags = EP_MDIO_MSR_LSTATUS;
	volatile uint16_t msr;

	if (dev->flags & EP_DEV_AUTONEG_ENABLED)
		flags |= EP_MDIO_MSR_ANEGCOMPLETE;

	msr = ep_pcs_read(dev, EP_MDIO_MSR);
	msr = ep_pcs_read(dev, EP_MDIO_MSR);	/* Read this flag twice to make sure the status is updated */

	//pp_printf("MSR %x\n", msr);

	if (lpa)
		*lpa = ep_pcs_read(dev, EP_MDIO_LPA);

	return (msr & flags) == flags ? 1 : 0;
}

int ep_get_bitslide(struct wr_endpoint_device* dev)
{
	return PICOS_PER_SERIAL_BIT *
	    (( ep_pcs_read(dev, EP_MDIO_WR_SPEC) & EP_MDIO_WR_SPEC_BSLIDE_MASK) >> EP_MDIO_WR_SPEC_BSLIDE_SHIFT);
}

/* Returns the TX/RX latencies. They are valid only when the link is up. */
int ep_get_deltas(struct wr_endpoint_device* dev, int *delta_tx, int *delta_rx)
{
	/* fixme: RX/TX delays related to HW (except SFP) should be stored in
	 * calibration block in the EEPROM on the FMC. */
	return 0;
}

int ep_timestamper_cal_pulse(struct wr_endpoint_device* dev)
{
	ep_write(dev, EP_REG_TSCR, ep_read(dev, EP_REG_TSCR) | EP_TSCR_RX_CAL_START );
	timer_delay_ms(1);
	return ep_read(dev, EP_REG_TSCR) & EP_TSCR_RX_CAL_RESULT ? 1 : 0;
}

int ep_sfp_enable(struct wr_endpoint_device* dev, int ena)
{
	uint32_t val;

	val = ep_pcs_read(dev, EP_MDIO_ECTRL);
	if(ena)
		val &= (~EP_MDIO_ECTRL_SFP_TX_DISABLE);
	else
		val |= EP_MDIO_ECTRL_SFP_TX_DISABLE;

	ep_pcs_write(dev, EP_MDIO_ECTRL, val);

	return 0;
}
