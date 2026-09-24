/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 GSI (www.gsi.de)
 * Author: Wesley W. Terpstra <w.terpstra@gsi.de>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <wrc.h>

#include "shell.h"
#include "storage.h"
#include "net.h"
#include "dev/endpoint.h"
#include "ppsi/lib.h"


static void decode_port(const char *str, int *port)
{
	if( !str )
		*port = 0;
	else
		*port = atoi(str);
}


static const char * const mac_cmds[] =
{
	 [0] = "get",
	 [1] = "getp",
	 [2] = "set",
	 [3] = "setp",
};

static int cmd_mac(const char *args[])
{
	int icmd;
	unsigned char mac[6];
	char buf[32];
	int port;

	if (args[0])
		icmd = sub_cmd(mac_cmds, ARRAY_SIZE(mac_cmds), args);
	else
		icmd = 0; /* default is 'get' */

	switch (icmd) {
	case 0:
		/* get current MAC */
		copy_eth_addr(mac, wrc_endpoint_dev.mac_addr);
		break;
	case 1:
		/* get persistent MAC */
		decode_port(args[1], &port);
		storage_get_persistent_mac(port, mac);
		break;
	case 2:
		if (!args[1])
			return -1;
		decode_mac(args[1], mac);
		ep_set_mac_addr(&wrc_endpoint_dev, mac);
		ep_pfilter_init_default(&wrc_endpoint_dev);
		break;
	case 3:
		if (!args[1])
			return -1;
		decode_mac(args[1], mac);
		decode_port(args[2], &port);
		storage_set_persistent_mac(port, mac);
		break;
	default:
		return -1;
	}

	pp_printf("MAC-address: %s\n", format_mac(buf, mac));
	return 0;
}

DEFINE_WRC_COMMAND(mac) = {
	.name = "mac",
	.exec = cmd_mac,
};
