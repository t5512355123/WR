/*
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdint.h>
#include <stdio.h>
#include <errno.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <time.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <sys/time.h>
#include <sys/utsname.h>
#define _GNU_SOURCE /* Needed with libmusl to have the udphdr we expect */
#include <net/if.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/udp.h>
#include <netinet/if_ether.h>
#include <linux/if_packet.h>
#include <net/if_arp.h>

#include <ppsi/ieee1588_types.h> /* from ../include */
#include "decent_types.h"
#include "ptpdump.h"

#ifndef ETH_P_1588
#define ETH_P_1588     0x88F7
#endif

void print_spaces(struct pp_time *ti)
{
	static struct pp_time prev_ti;
	int i, diffms;

	if (prev_ti.secs) {

		diffms = (ti->secs - prev_ti.secs) * 1000
			+ ((ti->scaled_nsecs >> 16) / 1000 / 1000)
			- ((prev_ti.scaled_nsecs) / 1000 / 1000);
		/* empty lines, one every .25 seconds, at most 10 of them */
		for (i = 250; i < 2500 && i < diffms; i += 250)
			printf("\n");
		printf("TIMEDELTA: %i ms\n", diffms);
	}
	prev_ti = *ti;
}


int main(int argc, char **argv)
{
	int sock, ret;
	struct packet_mreq req;
	struct sockaddr_ll addr;
	struct ifreq ifr;
	char *ifname = "eth0";
	int val;

	sock = socket(PF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
	if (sock < 0) {
		fprintf(stderr, "%s: socket(): %s\n", argv[0], strerror(errno));
		exit(1);
	}
	if (argc > 1)
		ifname = argv[1];

	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, ifname);
	if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0) {
		fprintf(stderr, "%s: ioctl(GETIFINDEX(%s)): %s\n", argv[0],
			ifname, strerror(errno));
		exit(1);
	}

	memset(&addr, 0, sizeof(addr));
	addr.sll_family = AF_PACKET;
	addr.sll_protocol = htons(ETH_P_ALL); /* ETH_P_1588, but also vlan */
	addr.sll_ifindex = ifr.ifr_ifindex;
	addr.sll_pkttype = PACKET_MULTICAST;
	if (bind(sock, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		fprintf(stderr, "%s: bind(%s)): %s\n", argv[0],
			ifname, strerror(errno));
		exit(1);
	}

	fprintf(stderr, "Dumping PTP packets from interface \"%s\"\n", ifname);

	memset(&req, 0, sizeof(req));
	req.mr_ifindex = ifr.ifr_ifindex;
	req.mr_type = PACKET_MR_PROMISC;


	if (setsockopt(sock, SOL_PACKET, PACKET_ADD_MEMBERSHIP,
		       &req, sizeof(req)) < 0) {
		fprintf(stderr, "%s: set promiscuous(%s): %s\n", argv[0],
			ifname, strerror(errno));
		exit(1);
	}

	/* enable AUXDATA */
	val = 1;
	if (setsockopt(sock, SOL_PACKET, PACKET_AUXDATA,
		       &val, sizeof(val)) < 0) {
		fprintf(stderr, "%s: set auxdata(%s): %s\n", argv[0],
			ifname, strerror(errno));
		exit(1);
	}

	/* Ok, now we are promiscuous. Just read stuff forever */
	while(1) {
		struct ethhdr *eth;
		struct pp_vlanhdr *vhdr;
		struct iphdr *ip;
		unsigned char buf[1500];
		struct pp_time ti;
		struct timeval tv;
		struct msghdr msg;
		struct iovec entry;
		struct sockaddr_ll from_addr;
		union {
			struct cmsghdr cm;
			char buf[CMSG_SPACE(sizeof(struct tpacket_auxdata))];
		} control;
		struct cmsghdr *cmsg;
		struct tpacket_auxdata *aux = NULL;
		int vlan = 0;
		int len, proto;

		memset(&msg, 0, sizeof(msg));
		memset(&from_addr, 0, sizeof(from_addr));
		msg.msg_iov = &entry;
		msg.msg_iovlen = 1;
		entry.iov_base = buf;
		entry.iov_len = sizeof(buf);
		msg.msg_name = (caddr_t)&from_addr;
		msg.msg_namelen = sizeof(from_addr);
		msg.msg_control = &control;
		msg.msg_controllen = sizeof(control);

		len = recvmsg(sock, &msg, MSG_TRUNC);

		/* Get the receive time, copy it to TimeInternal */
		gettimeofday(&tv, NULL);
		ti.secs = tv.tv_sec;
		ti.scaled_nsecs = (tv.tv_usec * 1000LL) << 16;

		if (len > sizeof(buf))
			len = sizeof(buf);

		for (cmsg = CMSG_FIRSTHDR(&msg);
		     cmsg;
		     cmsg = CMSG_NXTHDR(&msg, cmsg)) {
			void *dp = CMSG_DATA(cmsg);

			if (cmsg->cmsg_level == SOL_PACKET &&
			    cmsg->cmsg_type == PACKET_AUXDATA)
				aux = (struct tpacket_auxdata *)dp;
		}

		/* now only print ptp packets */
		if (len < ETH_HLEN)
			continue;

		eth = (void *)buf;
		ip = (void *)(buf + ETH_HLEN);

		proto = ntohs(eth->h_proto);

		/* get the VLAN for incomming frames */
		vlan = -1;
		if (aux && aux->tp_status & TP_STATUS_VLAN_VALID) {
			/* already in the network order */
			vlan = aux->tp_vlan_tci & 0xfff;
		}

		/* Get the VLAN for outgoing frames */
		if (proto == 0x8100) { /* VLAN is visible (e.g.: outgoing) */
			vhdr = (void *)buf;
			proto = ntohs(vhdr->h_proto);
			ip = (void *)(buf + sizeof(*vhdr));
			vlan = ntohs(vhdr->h_tci) & 0xfff;
		}

		switch(proto) {
		case ETH_P_IP:
		{
			struct udphdr *udp = (void *)(ip + 1);
			int udpdest = ntohs(udp->dest);

			/*
			 * Filter before calling the dump function, otherwise
			 * we'll report TIMEDELAY for not-relevant frames
			 */
			if (len < ETH_HLEN + sizeof(*ip) + sizeof(*udp))
				continue;
			if (ip->protocol != IPPROTO_UDP)
				continue;
			if (udpdest != 319 && udpdest != 320)
				continue;
			print_spaces(&ti);
			ret = dump_udppkt("", buf, len, &ti, vlan);
			break;
		}

		case ETH_P_1588:
			print_spaces(&ti);
			ret = dump_1588pkt("", buf, len, &ti, vlan);
			break;
		default:
			ret = -1;
			continue;
		}
		if (ret == 0)
			putchar('\n');
		fflush(stdout);
	}

	return 0;
}

#if 0
char *format_hex(char *s, const unsigned char *mac, int cnt)
{
	int i;
	*s = '\0';
	for (i = 0; i < cnt; i++) {
		sprintf(s, "%s%02x:", s, mac[i]);
	}

	/* remove last colon */
	s[cnt * 3 - 1] = '\0'; /* cnt * strlen("FF:") - 1 */
	return s;
}

char *format_hex8(char *s, const unsigned char *mac)
{
	return format_hex(s, mac, 8);
}

char *format_mac(char *s, const unsigned char *mac)
{
	format_hex(s, mac, 6);
	return s;
}
#endif
