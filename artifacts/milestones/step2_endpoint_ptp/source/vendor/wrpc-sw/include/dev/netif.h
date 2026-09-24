/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __WRC_NETIF_H
#define __WRC_NETIF_H

#define NETIF_LINK_DOWN 0
#define NETIF_LINK_WENT_UP 1
#define NETIF_LINK_WENT_DOWN 2
#define NETIF_LINK_UP 3

struct wrc_netif_device
{
	struct wr_endpoint_device* ep;
	struct wr_minic *nic;

	uint32_t phase_transition;
};

int netif_register_device(struct wr_endpoint_device *ep, struct wr_minic *nic);
int netif_get_device_count(void);
struct wrc_netif_device* netif_get_device(unsigned idx);
void netif_set_phase_transition(unsigned idx, uint32_t phase);

#endif
