/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#include "wrc.h"

#include "dev/endpoint.h"
#include "dev/netif.h"

#include "board.h"
#include "dev/rxts_calibrator.h"

#ifndef WRC_NETIF_MAX_DEVICES
    #define WRC_NETIF_MAX_DEVICES 2
#endif

static unsigned char netif_n_count = 0;
static struct wrc_netif_device netif_devs[WRC_NETIF_MAX_DEVICES];

void netif_set_phase_transition(unsigned idx, uint32_t phase)
{
	netif_devs[idx].phase_transition = phase;
}

int netif_register_device(struct wr_endpoint_device *ep, struct wr_minic *nic)
{
    if( netif_n_count >= WRC_NETIF_MAX_DEVICES )
        return -1;

    struct wrc_netif_device *ndev = &netif_devs[netif_n_count];

    ndev->ep = ep;
    ndev->nic = nic;
    ndev->phase_transition = DEFAULT_T24P_PHASE_TRANSITION;

    dev_dbg("Registered network interface %u @ %p\n", netif_n_count, ndev->ep->base );

    netif_n_count++;

    return 0;
}

int netif_get_device_count(void)
{
    return netif_n_count;
}

struct wrc_netif_device* netif_get_device(unsigned idx)
{
    return &netif_devs[idx];
}
