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

#include "ppsi/lib.h"
#include <lib/ipv4.h>
#include <netconsole.h>
#include <shell.h>

static void print_netconsole_status(void)
{
	char buf[20];

	/* print netconsole's status */
	switch (netconsole_status) {
	case NETCONSOLE_ENABLED:
		/* Print peer's MAC and IP */
		pp_printf("netconsole's peer: ");
		format_mac(buf, (void *)&netconsole_sock_addr.mac);
		pp_printf("MAC: %s ", buf);
		format_ip(buf, (void *)&netconsole_udp_addr.daddr);
		pp_printf("IP: %s ", buf);
		pp_printf("port: %d\n", netconsole_udp_addr.dport);
		break;
	case NETCONSOLE_WAIT:
		pp_printf("netconsole is waiting for peer\n");
		break;
	case NETCONSOLE_DISABLED:
		pp_printf("netconsole disabled\n");
		break;
	default:
		break;
	}
}

static int cmd_netconsole(const char *args[])
{
	if (!args[0]) {
		/* do nothing here, later print status */
	} else if (!strcasecmp(args[0], "wait")) {
		/* Disable netconsole */
		netconsole_status = NETCONSOLE_WAIT;
	} else if (!strcasecmp(args[0], "disable")) {
		/* Disable permanently netconsole */
		netconsole_status = NETCONSOLE_DISABLED;
	} else if (args[0] && args[1] && args[2]) {
		/* Set MAC and IP for netconsole peer */
		decode_mac(args[0], (void *)&netconsole_sock_addr.mac);
		decode_ip(args[1], (void *)&netconsole_udp_addr.daddr);
		netconsole_udp_addr.dport = atoi(args[2]);
		netconsole_status = NETCONSOLE_ENABLED;
	} else {
		pp_printf("uage: netconsole wait | disable | "
			  "<MAC> <IP> <port> \n");
		return -EINVAL;
	}

	print_netconsole_status();

	return 0;
}

DEFINE_WRC_COMMAND(netconsole) = {
	.name = "netconsole",
	.exec = cmd_netconsole,
};
