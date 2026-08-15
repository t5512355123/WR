/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Adam Wujek <adam.wujek@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <string.h>
#include "wrc.h"
#include "wrpc.h"
#include "wrc_global.h"

#include "ipv4.h"
#include "net.h"
#include "shell.h"
#include "netconsole.h"
#include "dev/netif.h"

#ifdef CONFIG_NETCONSOLE_DEF_WAIT
#define NETCONSOLE_DEF_VAL NETCONSOLE_WAIT
#else
#define NETCONSOLE_DEF_VAL NETCONSOLE_DISABLED
#endif

static DECLARE_WRPC_SOCKET(netconsole_socket, 152);
static struct wrpc_socket *netconsole_socket;
static unsigned char *cmd_rx_p = NULL;
/* net headers + cmd len */
static uint8_t tx_buf[UDP_END + SH_MAX_LINE_LEN + 1];
static uint8_t rx_buf[UDP_END + SH_MAX_LINE_LEN + 1];
struct wr_sockaddr netconsole_sock_addr;
int netconsole_status = NETCONSOLE_DEF_VAL;
struct wr_udp_addr netconsole_udp_addr;

/* init for netconsole task */
void netconsole_init(void)
{
	struct wrc_netif_device *nif = netif_get_device(0);

	netconsole_socket = ptpd_netif_create_socket
	  (GET_WRPC_SOCKET(netconsole_socket), LEN_WRPC_SOCKET(netconsole_socket),
	   NULL, PTPD_SOCK_UDP, NETCONSOLE_PORT, nif);
}

int netconsole_read_byte(void)
{
	if (cmd_rx_p && *cmd_rx_p != 0)
		return *(cmd_rx_p++);
	return -1;
}

/* NOTE: pp_printf will not work in this function
 * because it can be called from pp_printf */
int netconsole_write_string(const char *s)
{
	static int len = 0;
	const uint8_t *p;
	static uint8_t *d = NULL;
	static int rec_level = 0;

	if (netconsole_status != NETCONSOLE_ENABLED)
		return 0;

	/* Prevent recursive calls when net verbose configured.
	 * NOTE: Even with the following if, NET_IS_VERBOSE does not work
	 * with netconsole */
	if (rec_level > 0)
		return 0;

	rec_level++;
	
	p = (uint8_t *)s;
	while (1) {
		if (!d) {
			d = &tx_buf[UDP_END];
			len = 0;
			}
		if (!*p) {
			break;
		}

		*d = *p;
		len++;
		/* send packet on:
		 * --newline
		 * --"#", so prompt is send
		 * --max line length
		 */
		if (*d == '\n' || *d == '#' || len == SH_MAX_LINE_LEN) {
			len += UDP_END;
			netconsole_udp_addr.sport = htons(NETCONSOLE_PORT);
			getIP((void *)&netconsole_udp_addr.saddr);
			fill_udp((uint8_t *)tx_buf, len, &netconsole_udp_addr);
			ptpd_netif_sendto(netconsole_socket,
					  &netconsole_sock_addr, tx_buf, len,
					  0);
			d = NULL;
			/* len is cleared when d == NULL */
			p++;
			continue;
		}
		p++;
		d++;
	}

	rec_level--;
	return 0;
}


int netconsole_poll(void)
{
	int len;

	if (ip_status == IP_TRAINING
	    || netconsole_status == NETCONSOLE_DISABLED) {
		/* can't do netconsole w/o an address...
		 * or netconsole disabled */
		return 0;
	}

	if ((len = ptpd_netif_recvfrom(netconsole_socket,
				       &netconsole_sock_addr, rx_buf,
				       sizeof(rx_buf), NULL)
	    ) > 0) {
		if (check_dest_ip(rx_buf)) {
			/* wrong destination IP */
			return 0;
		}

		rx_buf[len] = 0;

		/* copy peer's IP address and port */
		memcpy(&netconsole_udp_addr.daddr, rx_buf + IP_SOURCE, 4);
		memcpy(&netconsole_udp_addr.dport, rx_buf + UDP_SPORT, 2);

		cmd_rx_p = &rx_buf[UDP_END];

		netconsole_status = NETCONSOLE_ENABLED;

		return 1;
	}
	return 0;
}
