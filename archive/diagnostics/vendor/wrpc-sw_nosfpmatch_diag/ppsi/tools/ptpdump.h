#ifndef __PTPDUMP_H__
#define __PTPDUMP_H__

#include <ppsi/ppsi.h>
#if __STDC_HOSTED__
#define _GNU_SOURCE /* Needed with libmusl to have the udphdr we expect */
#include <time.h>
#include <sys/time.h>
#include <netinet/ip.h>		/* struct iphdr */
#include <netinet/udp.h>	/* struct udphdr */
#include <netinet/if_ether.h>	/* struct ethhdr */
#else
#include "../lib/network_types.h"
#define printf pp_printf
#endif

int dump_udppkt(char *prefix, void *buf, int len,
		const struct pp_time *t, int vlan);
int dump_payloadpkt(char *prefix, void *buf, int len,
		    const struct pp_time *t);
int dump_1588pkt(char *prefix, void *buf, int len, const struct pp_time *t,
		 int vlan);

#endif /* __PTPDUMP_H__ */
