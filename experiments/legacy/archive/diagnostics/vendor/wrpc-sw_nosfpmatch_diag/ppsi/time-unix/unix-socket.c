/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 * Based on PTPd project v. 2.1.0 (see AUTHORS for details)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

/* Socket interface for GNU/Linux (and most likely other posix systems) */

#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <net/ethernet.h>
#include <arpa/inet.h>
#include <linux/if_packet.h>
#include <linux/if_vlan.h>

#include <ppsi/ppsi.h>
#include "ptpdump.h"
#include "../arch-unix/include/ppsi-unix.h"

/* unix_recv_msg uses recvmsg for timestamp query */
static int unix_recv_msg(struct pp_instance *ppi, int fd, void *pkt, int len,
			 struct pp_time *t)
{
	struct ethhdr *hdr = pkt;
	ssize_t ret;
	struct msghdr msg;
	struct iovec vec[1];
	int i;

	union {
		struct cmsghdr cm;
		char control[512];
	} cmsg_un;

	struct cmsghdr *cmsg;
	struct timeval *tv;
	struct tpacket_auxdata *aux = NULL;

	vec[0].iov_base = pkt;
	vec[0].iov_len = PP_MAX_FRAME_LENGTH;

	memset(&msg, 0, sizeof(msg));
	memset(&cmsg_un, 0, sizeof(cmsg_un));

	/* msg_name, msg_namelen == 0: not used */
	msg.msg_iov = vec;
	msg.msg_iovlen = 1;
	msg.msg_control = cmsg_un.control;
	msg.msg_controllen = sizeof(cmsg_un.control);

	ret = recvmsg(fd, &msg, MSG_DONTWAIT);
	if (ret <= 0) {
		if (errno == EAGAIN || errno == EINTR)
			return 0;

		return ret;
	}
	if (msg.msg_flags & MSG_TRUNC) {
		/* If we are in VLAN mode, we get everything. This is ok */
		if (ppi->proto != PPSI_PROTO_VLAN)
			pp_error("%s: truncated message\n", __func__);
		return PP_RECV_DROP; /* like "dropped" */
	}
	/* get time stamp of packet */
	if (msg.msg_flags & MSG_CTRUNC) {
		pp_error("%s: truncated ancillary data\n", __func__);
		return 0;
	}

	tv = NULL;
	for (cmsg = CMSG_FIRSTHDR(&msg); cmsg != NULL;
	     cmsg = CMSG_NXTHDR(&msg, cmsg)) {

		if (cmsg->cmsg_level == SOL_SOCKET &&
		    cmsg->cmsg_type == SCM_TIMESTAMP)
			tv = (struct timeval *)CMSG_DATA(cmsg);

		if (cmsg->cmsg_level == SOL_PACKET &&
		    cmsg->cmsg_type == PACKET_AUXDATA)
			aux = (struct tpacket_auxdata *)CMSG_DATA(cmsg);
	}

	if (tv) {
		t->secs = tv->tv_sec + DSPRO(ppi)->currentUtcOffset;
		t->scaled_nsecs = (uint64_t)(tv->tv_usec * 1000) << 16;
	} else {
		/*
		 * get the recording time here, even though it may  put a big
		 * spike in the offset signal sent to the clock servo
		 */
		TOPS(ppi)->get(ppi, t);
	}

	/* aux is only there if we asked for it, thus PROTO_VLAN */
	if (aux) {
		/* With PROTO_VLAN, we bound to ETH_P_ALL: we got all frames */
		if (hdr->h_proto != htons(ETH_P_1588))
			return PP_RECV_DROP; /* no error message */
		/* Also, we got the vlan, and we can discard it if not ours */
		for (i = 0; i < ppi->nvlans; i++)
			if (ppi->vlans[i] == (aux->tp_vlan_tci & 0xfff))
				break; /* ok */
		if (i == ppi->nvlans)
			return PP_RECV_DROP; /* not ours: say it's dropped */
		ppi->peer_vid = ppi->vlans[i];
	} else {
		ppi->peer_vid = 0;
	}

	if (ppsi_drop_rx()) {
		pp_diag(ppi, frames, 1, "Drop received frame\n");
		return PP_RECV_DROP;
	}

	/* This is not really hw... */
	pp_diag(ppi, time, 1, "recv stamp: %lli.%09i (%s)\n",
		(long long)t->secs, (int)(t->scaled_nsecs >> 16),
				    tv ? "kernel" : "user");
	return ret;
}

/* Receive and send is *not* so trivial */
static int unix_net_recv(struct pp_instance *ppi, void *pkt, int len,
			 struct pp_time *t)
{
	struct pp_channel *ch1, *ch2;
	struct ethhdr *hdr = pkt;
	int ret;

	switch(ppi->proto) {
	case PPSI_PROTO_RAW:
	case PPSI_PROTO_VLAN:
		ch2 = ppi->ch + PP_NP_GEN;

		ret = unix_recv_msg(ppi, ch2->fd, pkt, len, t);
		if (ret <= 0)
			return ret;
		if (hdr->h_proto != htons(ETH_P_1588))
			return PP_RECV_DROP; /* like "dropped", so no error message */

		memcpy(ppi->peer, hdr->h_source, ETH_ALEN);
		if (pp_diag_allow(ppi, frames, 2)) {
			if (ppi->proto == PPSI_PROTO_VLAN)
				pp_printf("recv: VLAN %i\n", ppi->peer_vid);
			dump_1588pkt("recv: ", pkt, ret, t, -1);
		}
		return ret;

	case PPSI_PROTO_UDP:
		/* we can return one frame only, always handle EVT msgs
		 * before GEN */
		ch1 = &(ppi->ch[PP_NP_EVT]);
		ch2 = &(ppi->ch[PP_NP_GEN]);

		ret = -1;
		if (ch1->pkt_present)
			ret = unix_recv_msg(ppi, ch1->fd, pkt, len, t);
		else if (ch2->pkt_present)
			ret = unix_recv_msg(ppi, ch2->fd, pkt, len, t);
		if (ret <= 0)
			return ret;
		/* We can't save the peer's mac address in UDP mode */
		if (pp_diag_allow(ppi, frames, 2))
			dump_payloadpkt("recv: ", pkt, ret, t);
		return ret;

	default:
		return -1;
	}
}

static int unix_net_send(struct pp_instance *ppi, void *pkt, int len,enum pp_msg_format msg_fmt)
{
	const struct pp_msgtype_info *mf = pp_msgtype_info + msg_fmt;
	int chtype = mf->chtype;
	struct sockaddr_in addr;
	struct ethhdr *hdr = pkt;
	struct pp_vlanhdr *vhdr = pkt;
	struct pp_channel *ch = ppi->ch + chtype;
	struct pp_time *t = &ppi->last_snt_time;
	int delay_mechanism =  mf->delay_mechanism;
	static const uint16_t udpport[] = {
		[PP_NP_GEN] = PP_GEN_PORT,
		[PP_NP_EVT] = PP_EVT_PORT,
	};
	static const uint8_t macaddr[MECH_MAX_SUPPORTED + 1][ETH_ALEN] = {
		[MECH_E2E] = PP_MCAST_MACADDRESS,
		[MECH_P2P] = PP_PDELAY_MACADDRESS,
	};
	int ret;

	/* To fake a network frame loss, set the timestamp and do not send */
	if (ppsi_drop_tx()) {
		TOPS(ppi)->get(ppi, t);
		pp_diag(ppi, frames, 1, "Drop sent frame\n");
		return len;
	}

	switch(ppi->proto) {
	case PPSI_PROTO_RAW:
		/* raw socket implementation always uses gen socket */
		ch = ppi->ch + PP_NP_GEN;
		hdr->h_proto = htons(ETH_P_1588);

		memcpy(hdr->h_dest, macaddr[delay_mechanism], ETH_ALEN);
		memcpy(hdr->h_source, ch->addr, ETH_ALEN);

		TOPS(ppi)->get(ppi, t);

		ret = send(ch->fd, hdr, len, 0);
		if (ret < 0) {
			pp_diag(ppi, frames, 0, "send failed: %s\n",
				strerror(errno));
			return ret;
		}
		pp_diag(ppi, time, 1, "send stamp: %lli.%09i (%s)\n",
			(long long)t->secs, (int)(t->scaled_nsecs >> 16),
			"user");
		if (pp_diag_allow(ppi, frames, 2))
			dump_1588pkt("send: ", pkt, len, t, -1);
		return ret;

	case PPSI_PROTO_VLAN:
		/* similar to sending raw frames, but w/ different header */
		ch = ppi->ch + PP_NP_GEN;
		vhdr->h_proto = htons(ETH_P_1588);
		vhdr->h_tci = htons(ppi->peer_vid); /* prio is 0 */
		vhdr->h_tpid = htons(0x8100);

		memcpy(hdr->h_dest, macaddr[delay_mechanism], ETH_ALEN);
		memcpy(vhdr->h_source, ch->addr, ETH_ALEN);

		TOPS(ppi)->get(ppi, t);

		ret = send(ch->fd, vhdr, len, 0);
		if (ret < 0) {
			pp_diag(ppi, frames, 0, "send failed: %s\n",
				strerror(errno));
			return ret;
		}
		pp_diag(ppi, time, 1, "send stamp: %lli.%09i (%s)\n",
			(long long)t->secs, (int)(t->scaled_nsecs >> 16),
			"user");
		if (pp_diag_allow(ppi, frames, 2))
			dump_1588pkt("send: ", vhdr, len, t, ppi->peer_vid);

	case PPSI_PROTO_UDP:
		addr.sin_family = AF_INET;
		addr.sin_port = htons(udpport[chtype]);
		addr.sin_addr.s_addr = ppi->mcast_addr[delay_mechanism];

		TOPS(ppi)->get(ppi, t);

		ret = sendto(ppi->ch[chtype].fd, pkt, len, 0,
			     (struct sockaddr *)&addr,
			     sizeof(struct sockaddr_in));
		if (ret < 0) {
			pp_diag(ppi, frames, 0, "send failed: %s\n",
				strerror(errno));
			return ret;
		}
		pp_diag(ppi, time, 1, "send stamp: %lli.%09i (%s)\n",
			(long long)t->secs, (int)(t->scaled_nsecs >> 16),
			"user");
		if (pp_diag_allow(ppi, frames, 2))
			dump_payloadpkt("send: ", pkt, len, t);
		return ret;

	default:
		return -1;
	}
}

/* To open a channel we must bind to an interface and so on */
static int unix_open_ch_raw(struct pp_instance *ppi, char *ifname, int chtype)
{
	int sock = -1;
	int temp, iindex;
	struct ifreq ifr;
	struct sockaddr_in addr;
	struct sockaddr_ll addr_ll;
	struct packet_mreq pmr;
	char *context;

	/* open socket */
	context = "socket()";
	sock = socket(PF_PACKET, SOCK_RAW | SOCK_NONBLOCK, ETH_P_1588);
	if (sock < 0)
		goto err_out;

	/* hw interface information */
	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, ifname);
	context = "ioctl(SIOCGIFINDEX)";
	if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0)
		goto err_out;

	iindex = ifr.ifr_ifindex;
	context = "ioctl(SIOCGIFHWADDR)";
	if (ioctl(sock, SIOCGIFHWADDR, &ifr) < 0)
		goto err_out;

	memcpy(ppi->ch[chtype].addr, ifr.ifr_hwaddr.sa_data, 6);

	/* bind */
	memset(&addr_ll, 0, sizeof(addr));
	addr_ll.sll_family = AF_PACKET;
	if (ppi->nvlans)
		addr_ll.sll_protocol = htons(ETH_P_ALL);
	else
		addr_ll.sll_protocol = htons(ETH_P_1588);
	addr_ll.sll_ifindex = iindex;
	context = "bind()";
	if (bind(sock, (struct sockaddr *)&addr_ll,
		 sizeof(addr_ll)) < 0)
		goto err_out;

	/* accept the multicast address for raw-ethernet ptp */
	memset(&pmr, 0, sizeof(pmr));
	pmr.mr_ifindex = iindex;
	pmr.mr_type = PACKET_MR_MULTICAST;
	pmr.mr_alen = ETH_ALEN;
	memcpy(pmr.mr_address, PP_MCAST_MACADDRESS, ETH_ALEN);
	setsockopt(sock, SOL_PACKET, PACKET_ADD_MEMBERSHIP,
		   &pmr, sizeof(pmr)); /* lazily ignore errors */
	/* add peer delay multicast address */
	memcpy(pmr.mr_address, PP_PDELAY_MACADDRESS, ETH_ALEN);
	setsockopt(sock, SOL_PACKET, PACKET_ADD_MEMBERSHIP,
		   &pmr, sizeof(pmr)); /* lazily ignore errors */


	/* make timestamps available through recvmsg() -- FIXME: hw? */
	temp = 1;
	setsockopt(sock, SOL_SOCKET, SO_TIMESTAMP,
		   &temp, sizeof(int));

	if (ppi->proto == PPSI_PROTO_VLAN) {
		/* allow the kernel to tell us the source VLAN */
		setsockopt(sock, SOL_PACKET, PACKET_AUXDATA,
			   &temp, sizeof(temp));
	}

	ppi->ch[chtype].fd = sock;
	return 0;

err_out:
	pp_printf("%s: %s: %s\n", __func__, context, strerror(errno));
	if (sock >= 0)
		close(sock);
	ppi->ch[chtype].fd = -1;
	return -1;
}

static int unix_open_ch_udp(struct pp_instance *ppi, char *ifname, int chtype)
{
	int sock = -1;
	int temp;
	struct in_addr iface_addr, net_addr;
	struct ifreq ifr;
	struct sockaddr_in addr;
	struct ip_mreq imr;
	char addr_str[INET_ADDRSTRLEN];
	char *context;

	context = "socket()";
	sock = socket(PF_INET, SOCK_DGRAM | SOCK_NONBLOCK, IPPROTO_UDP);
	if (sock < 0)
		goto err_out;

	ppi->ch[chtype].fd = sock;

	/* hw interface information */
	memset(&ifr, 0, sizeof(ifr));
	strcpy(ifr.ifr_name, ifname);
	context = "ioctl(SIOCGIFINDEX)";
	if (ioctl(sock, SIOCGIFINDEX, &ifr) < 0)
		goto err_out;

	context = "ioctl(SIOCGIFHWADDR)";
	if (ioctl(sock, SIOCGIFHWADDR, &ifr) < 0)
		goto err_out;

	memcpy(ppi->ch[chtype].addr, ifr.ifr_hwaddr.sa_data, 6);
	context = "ioctl(SIOCGIFADDR)";
	if (ioctl(sock, SIOCGIFADDR, &ifr) < 0)
		goto err_out;

	iface_addr.s_addr =
		((struct sockaddr_in *)&ifr.ifr_addr)->sin_addr.s_addr;

	pp_diag(ppi, frames, 2, "Local IP address used : %s\n",
		inet_ntoa(iface_addr));

	temp = 1; /* allow address reuse */
	if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR,
		       &temp, sizeof(int)) < 0)
		pp_printf("%s: ioctl(SO_REUSEADDR): %s\n", __func__,
			  strerror(errno));

	/* bind sockets */
	/* need INADDR_ANY to allow receipt of multi-cast and uni-cast
	 * messages */
	addr.sin_family = AF_INET;
	addr.sin_addr.s_addr = htonl(INADDR_ANY);
	addr.sin_port = htons(chtype == PP_NP_GEN
			      ? PP_GEN_PORT : PP_EVT_PORT);
	context = "bind()";
	if (bind(sock, (struct sockaddr *)&addr,
		 sizeof(struct sockaddr_in)) < 0)
		goto err_out;

	/* Init General multicast IP address */
	strcpy(addr_str, PP_DEFAULT_DOMAIN_ADDRESS);

	context = addr_str; errno = EINVAL;
	if (!inet_aton(addr_str, &net_addr))
		goto err_out;
	ppi->mcast_addr[MECH_E2E] = net_addr.s_addr;

	/* multicast sends only on specified interface */
	imr.imr_multiaddr.s_addr = net_addr.s_addr;
	imr.imr_interface.s_addr = iface_addr.s_addr;
	context = "setsockopt(IP_MULTICAST_IF)";
	if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF,
		       &imr.imr_interface.s_addr,
		       sizeof(struct in_addr)) < 0)
		goto err_out;

	/* join multicast group (for recv) on specified interface */
	context = "setsockopt(IP_ADD_MEMBERSHIP)";
	if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		       &imr, sizeof(struct ip_mreq)) < 0)
		goto err_out;

	/* Init Peer multicast IP address */
	strcpy(addr_str, PP_PDELAY_DOMAIN_ADDRESS);

	context = addr_str;
	errno = EINVAL;
	if (!inet_aton(addr_str, &net_addr))
		goto err_out;
	ppi->mcast_addr[MECH_P2P] = net_addr.s_addr;
	imr.imr_multiaddr.s_addr = net_addr.s_addr;

	/* join multicast group (for receiving) on specified interface */
	context = "setsockopt(IP_ADD_MEMBERSHIP)";
	if (setsockopt(sock, IPPROTO_IP, IP_ADD_MEMBERSHIP,
		       &imr, sizeof(struct ip_mreq)) < 0)
		goto err_out;

	/* End of General multicast Ip address init */

	/* set socket time-to-live */
	context = "setsockopt(IP_MULTICAST_TTL)";
	if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_TTL,
		       &OPTS(ppi)->ttl, sizeof(int)) < 0)
		goto err_out;

	/* forcibly disable loopback */
	temp = 0;
	context = "setsockopt(IP_MULTICAST_LOOP)";
	if (setsockopt(sock, IPPROTO_IP, IP_MULTICAST_LOOP,
		       &temp, sizeof(int)) < 0)
		goto err_out;

	/* make timestamps available through recvmsg() */
	context = "setsockopt(SO_TIMESTAMP)";
	temp = 1;
	if (setsockopt(sock, SOL_SOCKET, SO_TIMESTAMP,
		       &temp, sizeof(int)) < 0)
		goto err_out;

	ppi->ch[chtype].fd = sock;
	return 0;

err_out:
	pp_printf("%s: %s: %s\n", __func__, context, strerror(errno));
	if (sock >= 0)
		close(sock);
	ppi->ch[chtype].fd = -1;
	return -1;
}

static int unix_net_exit(struct pp_instance *ppi);

/*
 * Inits all the network stuff
 */

/* This function must be able to be called twice, and clean-up internally */
static int unix_net_init(struct pp_instance *ppi)
{
	int i;

	if (ppi->ch[0].fd > 0)
		unix_net_exit(ppi);

	/* The buffer is inside ppi, but we need to set pointers and align */
	pp_prepare_pointers(ppi);

	switch(ppi->proto) {
	case PPSI_PROTO_RAW:
		pp_diag(ppi, frames, 1, "unix_net_init raw Ethernet\n");

		/* raw sockets implementation always use gen socket */
		return unix_open_ch_raw(ppi, ppi->iface_name, PP_NP_GEN);

	case PPSI_PROTO_VLAN:
		pp_diag(ppi, frames, 1, "unix_net_init raw Ethernet "
			"with VLAN\n");

		/* same as PROTO_RAW above, the differences are minimal */
		return unix_open_ch_raw(ppi, ppi->iface_name, PP_NP_GEN);

	case PPSI_PROTO_UDP:
		if (ppi->nvlans) {
			/* If "proto udp" is set after setting vlans... */
			pp_printf("Error: can't use UDP with VLAN support\n");
			exit(1);
		}
		pp_diag(ppi, frames, 1, "unix_net_init UDP\n");
		for (i = PP_NP_GEN; i <= PP_NP_EVT; i++) {
			if (unix_open_ch_udp(ppi, ppi->iface_name, i))
				return -1;
		}
		return 0;

	default:
		return -1;
	}
}

/*
 * Shutdown all the network stuff
 */
static int unix_net_exit(struct pp_instance *ppi)
{
	struct ip_mreq imr;
	int fd;
	int i;

	switch(ppi->proto) {
	case PPSI_PROTO_RAW:
	case PPSI_PROTO_VLAN:
		fd = ppi->ch[PP_NP_GEN].fd;
		if (fd > 0) {
			close(fd);
			ppi->ch[PP_NP_GEN].fd = -1;
		}
		return 0;

	case PPSI_PROTO_UDP:
		for (i = PP_NP_GEN; i <= PP_NP_EVT; i++) {
			fd = ppi->ch[i].fd;
			if (fd < 0)
				continue;

			/* Close General Multicast */
			imr.imr_interface.s_addr = htonl(INADDR_ANY);
			imr.imr_multiaddr.s_addr = ppi->mcast_addr[MECH_E2E];
			setsockopt(fd, IPPROTO_IP, IP_DROP_MEMBERSHIP,
				   &imr, sizeof(struct ip_mreq));
			imr.imr_multiaddr.s_addr = ppi->mcast_addr[MECH_P2P];
			setsockopt(fd, IPPROTO_IP, IP_DROP_MEMBERSHIP,
				   &imr, sizeof(struct ip_mreq));
			close(fd);

			ppi->ch[i].fd = -1;
		}
		ppi->mcast_addr[MECH_E2E] = ppi->mcast_addr[MECH_P2P] = 0;
		return 0;

	default:
		return -1;
	}
}

static int unix_net_check_packet(struct pp_globals *ppg, int delay_ms)
{
	fd_set set;
	int i, j, k;
	int ret = 0;
	int maxfd = -1;
	struct unix_arch_data *arch_data = POSIX_ARCH(ppg);
	int old_delay_ms;

	old_delay_ms = arch_data->tv.tv_sec * 1000 +
		arch_data->tv.tv_usec / 1000;

	if ((delay_ms >=0 ) &&
		((old_delay_ms == 0) || (delay_ms < old_delay_ms))) {
		/* Wait for a packet or for the timeout */
		arch_data->tv.tv_sec = delay_ms / 1000;
		arch_data->tv.tv_usec = (delay_ms % 1000) * 1000;
	}

	FD_ZERO(&set);

	for (j = 0; j < ppg->nlinks; j++) {
		struct pp_instance *ppi = INST(ppg, j);
		int fd_to_set;

		/* Use either fd that is valid, irrespective of ether/udp */
		for (k = 0; k < 2; k++) {
			ppi->ch[k].pkt_present = 0;
			fd_to_set = ppi->ch[k].fd;
			if (fd_to_set < 0)
				continue;

			FD_SET(fd_to_set, &set);
			maxfd = fd_to_set > maxfd ? fd_to_set : maxfd;
		}
	}
	i = select(maxfd + 1, &set, NULL, NULL, &arch_data->tv);

	if ( i < 0 ) {
		if ( errno==EINVAL || errno==EINTR ) {
			arch_data->tv.tv_sec =
			arch_data->tv.tv_usec =0;
			return -1;
		} else {
			pp_error("%s: Errno=%d %s\n",__func__, errno, strerror(errno));
			exit(errno);
		}
	}
	if (i == 0)
		return 0;

	for (j = 0; j < ppg->nlinks; j++) {
		struct pp_instance *ppi = INST(ppg, j);
		int fd = ppi->ch[PP_NP_GEN].fd;

		if (fd >= 0 && FD_ISSET(fd, &set)) {
			ret++;
			ppi->ch[PP_NP_GEN].pkt_present = 1;
		}

		fd = ppi->ch[PP_NP_EVT].fd;

		if (fd >= 0 && FD_ISSET(fd, &set)) {
			ret++;
			ppi->ch[PP_NP_EVT].pkt_present = 1;
		}
	}
	return ret;
}

const struct pp_network_operations unix_net_ops = {
	.init = unix_net_init,
	.exit = unix_net_exit,
	.recv = unix_net_recv,
	.send = unix_net_send,
	.check_packet = unix_net_check_packet,
};

