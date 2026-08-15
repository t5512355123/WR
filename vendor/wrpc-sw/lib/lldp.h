/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 GSI (www.gsi.de)
 * Author: Cesar Prados <c.prados@gsi.de>
 *
 * LLDP transmit-only station
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __LLDP_H
#define __LLDP_H

#include "dev/minic.h"

#define LLDP_MCAST_MAC	"\x01\x80\xC2\x00\x00\x0E" /* 802.1AB-2005,
						      Table 8-1 */
#define LLDP_ETH_TYP	0x88CC	/* 802.1AB-2005, Table 8-2 */

#define LLDP_MAX_PKT_LEN	0x9E /* 158 bytes */
#define LLDP_HEADER		0x2
#define LLDP_SUBTYPE		0x1
#define MNT_IF_SUBTYPE		0x6
#define MNT_IF_NUM		10

#define LLDP_TX_TICK_INTERVAL	5000

#define CHASSIS_ID_TLV_LEN	(1 + ETH_ALEN) /* chassis ID subtype byte
						* + MAC Len */
#define CHASSIS_ID_TYPE_MAC	4	/* 802.1AB-2005, table 9-2 */
#define PORT_ID_TLV_LEN		(1 + ETH_ALEN) /* port ID subtype byte
						* + MAC Len */
#define PORT_ID_SUBTYPE_MAC	3	/* 802.1AB-2005, table 9-3 */
#define TTL_ID_TLV_LEN		2	/* 802.1AB-2005, Figure 9-6 */
#define TTL_BYTE_MSB		0
#define TTL_BYTE_LSB		1
#define PORT_NAME		"wr0"
#define IPLEN			4	/* len of IP address in bytes */
#define MNG_ADDR_LEN		(1 + IPLEN) /* MNT addr subtype + IPLEN */
#define MNG_ADDR_SUBTYPE_IPv4	1	/* ianaAddressFamilyNumbers MIB */
#define MNG_ADDR_SUBTYPE_MAC	6	/* ianaAddressFamilyNumbers MIB */
#define MNG_IF_NUM_SUBTYPE_IFINDEX	2 /* 802.1AB-2005, 9.5.9.5 */

/* D.2.1 IEEE802.1Q-2014 or F.2 IEEE802.1AB-2005 */
#define TLV_ORG_SPECIFIC	127
#define OUI8021			0x0080C2
#define TLV_VLANID_SUBTYPE	0x1

/* OS=Organization Specific */
#define TLV_OS_OUI8021_OFF	0
#define TLV_OS_SUBTYPE_OFF	3
#define TLV_OS_VLAN_OFF		4

enum TLV_TYPE {
		END_LLDP = 0,	/* mandatory TLVs */
		CHASSIS_ID,
		PORT_ID,
		TTL,
		PORT,		/* optional TLVs */
		SYS_NAME,
		SYS_DESCR,
		SYS_CAPLTY,
		MNG_ADD,
		VLAN_ID,	/* uses different TLV value, can be moved */
		TLV_MAX_TYPE,
		USER_DEF
		};

void lldp_init(void);
int lldp_poll(void);

#endif /* __LLDP_H */
