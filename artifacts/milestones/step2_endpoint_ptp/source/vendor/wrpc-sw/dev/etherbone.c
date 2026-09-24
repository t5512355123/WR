/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2020 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include "board.h"
#include "hw/etherbone-config.h"

void eb_setIP(unsigned char *IP)
{
	volatile unsigned int *eb_ip =
	    (unsigned int *)(BASE_ETHERBONE_CFG + EB_IPV4);
	unsigned int ip;

	ip = (IP[0] << 24) | (IP[1] << 16) | (IP[2] << 8) | (IP[3]);
	while (*eb_ip != ip)
		*eb_ip = ip;
}
