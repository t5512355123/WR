/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 GSI (www.gsi.de)
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <wrc.h>
#include <string.h>

#include "endianness.h"
#include "dev/endpoint.h"
#include "ipv4.h"
#include "net.h"
#include "dev/netif.h"
#include "wrc_global.h"

static DECLARE_WRPC_SOCKET(arp_socket, 128);
static struct wrpc_socket *arp_socket;

#define ARP_HTYPE	0
#define ARP_PTYPE	(ARP_HTYPE+2)
#define ARP_HLEN	(ARP_PTYPE+2)
#define ARP_PLEN	(ARP_HLEN+1)
#define ARP_OPER	(ARP_PLEN+1)
#define ARP_SHA		(ARP_OPER+2)
#define ARP_SPA		(ARP_SHA+6)
#define ARP_THA		(ARP_SPA+4)
#define ARP_TPA		(ARP_THA+6)
#define ARP_END		(ARP_TPA+4)

void arp_init(void)
{
	struct wr_sockaddr saddr;
	struct wrc_netif_device *nif = netif_get_device(0);

	/* Configure socket filter */
	memset(&saddr, 0, sizeof(saddr));
	memset(&saddr.mac, 0xFF, 6);	/* Broadcast */
	saddr.ethertype = htons(0x0806);	/* ARP */

	arp_socket = ptpd_netif_create_socket
	  (GET_WRPC_SOCKET(arp_socket), LEN_WRPC_SOCKET(arp_socket),
	   &saddr, PTPD_SOCK_RAW_ETHERNET, 0, nif);
}

static int process_arp(uint8_t * buf, int len)
{
	uint8_t hisMAC[6];
	uint8_t hisIP[4];
	uint8_t myIP[4];

	if (len < ARP_END)
		return 0;

	/* Is it ARP request targetting our IP? */
	getIP(myIP);
	if (buf[ARP_OPER + 0] != 0 ||
	    buf[ARP_OPER + 1] != 1 || memcmp(buf + ARP_TPA, myIP, 4))
		return 0;

	memcpy(hisMAC, buf + ARP_SHA, 6);
	memcpy(hisIP, buf + ARP_SPA, 4);

	// ------------- ARP ------------
	// HW ethernet
	buf[ARP_HTYPE + 0] = 0;
	buf[ARP_HTYPE + 1] = 1;
	// proto IP
	buf[ARP_PTYPE + 0] = 8;
	buf[ARP_PTYPE + 1] = 0;
	// lengths
	buf[ARP_HLEN] = 6;
	buf[ARP_PLEN] = 4;
	// Response
	buf[ARP_OPER + 0] = 0;
	buf[ARP_OPER + 1] = 2;
	// my MAC+IP
	copy_eth_addr(buf + ARP_SHA, wrc_endpoint_dev.mac_addr);
	memcpy(buf + ARP_SPA, myIP, 4);
	// his MAC+IP
	memcpy(buf + ARP_THA, hisMAC, 6);
	memcpy(buf + ARP_TPA, hisIP, 4);

	return ARP_END;
}

int arp_poll(void)
{
	uint8_t buf[ARP_END + 100];
	struct wr_sockaddr addr;
	int len;

	if (ip_status == IP_TRAINING)
		return 0;		/* can't do ARP w/o an address... */

	if ((len = ptpd_netif_recvfrom(arp_socket,
				       &addr, buf, sizeof(buf), 0)) > 0) {
		if ((len = process_arp(buf, len)) > 0)
			ptpd_netif_sendto(arp_socket, &addr, buf, len, 0);
		return 1;
	}
	return 0;
}

