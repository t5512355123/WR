/** @file lm32.c
 *  @brief Implement raw ethernet using mininic
 *
 *  Copyright (C) 2011-2012 GSI Helmholtz Centre for Heavy Ion Research GmbH 
 *
 *  All supported transports are included in the global eb_transports[].
 *
 *  @author Mathias Kreider <m.kreider@gsi.de>
 *
 *  @bug None!
 *
 *******************************************************************************
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 3 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *  
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library. If not, see <http://www.gnu.org/licenses/>.
 *******************************************************************************
 */

#define ETHERBONE_IMPL

#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include "ipv4.h"
#include "../format/bigendian.h"
#include "../etherbone.h"
#include "lm32.h"


#define IP_START	0
#define IP_VER_IHL	0
#define IP_DSCP_ECN     (IP_VER_IHL+1)	
#define IP_TOL		(IP_DSCP_ECN+1)
#define IP_ID		(IP_TOL+2)
#define IP_FLG_FRG	(IP_ID+2)
#define IP_TTL		(IP_FLG_FRG+2)
#define IP_PROTO	(IP_TTL+1)
#define IP_CHKSUM	(IP_PROTO+1)
#define IP_SPA		(IP_CHKSUM+2)
#define IP_DPA		(IP_SPA+4)
#define IP_END		(IP_DPA+4)

#define UDP_START	IP_END	
#define UDP_SPP		IP_END
#define UDP_DPP     	(UDP_SPP+2)	
#define UDP_LEN		(UDP_DPP+2)
#define UDP_CHKSUM	(UDP_LEN+2)
#define UDP_END		(UDP_CHKSUM+2)

#define ETH_HDR_LEN	14
#define IP_HDR_LEN	IP_END-IP_START
#define UDP_HDR_LEN	UDP_END-UDP_START
#define UDP_IP_HDR_LEN	UDP_HDR_LEN+IP_HDR_LEN


struct eb_transport_ops eb_transports[] = {
{
    EB_LM32_UDP_MTU,
    eb_lm32_udp_open,
    eb_lm32_udp_close,
    eb_lm32_udp_connect,
    eb_lm32_udp_disconnect,
    eb_lm32_udp_fdes,
    eb_lm32_udp_accept,
    eb_lm32_udp_poll,
    eb_lm32_udp_recv,
    eb_lm32_udp_send,
    eb_lm32_udp_send_buffer
}
};

const unsigned int eb_transport_size = sizeof(eb_transports) / sizeof(struct eb_transport_ops);


typedef unsigned int adress_type_t;

const adress_type_t MAC   = 1;
const adress_type_t IP    = 2;
const adress_type_t PORT  = 3;

const uint16_t myPort = 0xEBD0;

static char* strsplit(const char*  numstr, const char* delimeter);

static unsigned char* numStrToBytes(const char*  numstr, unsigned char* bytes,  unsigned char len,  unsigned char base, const char* delimeter);
static unsigned char* addressStrToBytes(const char* addressStr, unsigned char* addressBytes, adress_type_t addtype);

static uint16_t myIP_checksum(uint8_t *buf, int shorts);
static uint16_t udp_checksum(const uint8_t *hdrbuf, const uint8_t *databuf, uint16_t len);  
static uint8_t* createUdpIpHdr(struct eb_lm32_udp_link* linkp, uint8_t* hdrbuf, const uint8_t* databuf, uint16_t len);

wr_sockaddr_t saddr;

eb_status_t eb_lm32_udp_open(struct eb_transport* transportp, const char* port) {

  dbgprint("Entering eb_lm32_udp_open\n");
  struct eb_lm32_udp_transport* transport;
  eb_lm32_sock_t* sock4;
  
  /* Configure socket filter */
  memset(&saddr, 1, sizeof(saddr));
  strcpy(saddr.if_name, port);
  
  saddr.ethertype = htons(0x0800);	/* IP */
  saddr.family = PTPD_SOCK_RAW_ETHERNET;
   
  sock4 = ptpd_netif_create_socket(PTPD_SOCK_RAW_ETHERNET,
					      0, &saddr); 
  /* Failure if we can't get a protocol */
  if (sock4 == NULL) 
    return EB_BUSY;
  
  transport = (struct eb_lm32_udp_transport*)transportp;
  transport->socket4 = sock4;

  	
  dbgprint("Leaving eb_lm32_udp_open\n");
  return EB_OK;
}


eb_status_t eb_lm32_udp_connect(struct eb_transport* transportp, struct eb_link* linkp, const char* address) {
  
dbgprint("Entering eb_lm32_udp_connect\n");
	struct eb_lm32_udp_link* link;
  char * pch;
  eb_status_t stat = EB_FAIL;

  link = (struct eb_lm32_udp_link*)linkp;

	//a proper address string must contain, MAC, IP and port: "hw/11:22:33:44:55:66/udp/192.168.0.1/port/60368"
	//parse and fill link struct
		
	pch = (char*) address;
	if(pch != NULL)
	{
		if(strncmp("hw", pch, 2) == 0)
		{
			pch = strsplit(pch,"/");
			if(pch != NULL)
			{
				addressStrToBytes((const char*)pch, link->mac, MAC);
				pch = strsplit(pch,"/");
				if(pch != NULL)
				{
					if(strncmp("udp", pch, 3) == 0)
					{
						pch = strsplit(pch,"/");
						if(pch != NULL)	addressStrToBytes(pch, link->ipv4, IP);
						pch = strsplit(pch,"/");
						if(pch != NULL)
						if(strncmp("port", pch, 4) == 0)
						{
							pch = strsplit(pch,"/");
							if(pch != NULL)
							{
								//addressStrToBytes(pch, link->port, PORT);
								link->port = atoi (pch);
								stat = EB_OK;
								dbgprint("Mac, Ip and Port seem correct.\n");
								dbgprint("Found:\n");
								dbgprint("MAC:  %x:%x:%x:%x:%x:%x\n", 
									link->mac[0],link->mac[1],link->mac[2],link->mac[3],link->mac[4],link->mac[5]);
								dbgprint("IPV4: %x:%x:%x:%x\n", 
									link->ipv4[0],link->ipv4[1],link->ipv4[2],link->ipv4[3]);
								dbgprint("Port: %d\n", link->port);
							}		
						}		
					}
				}
			}
		}
	}
	dbgprint("Leaving eb_lm32_udp_connect\n");
	return stat;

}

EB_PRIVATE void eb_lm32_udp_disconnect(struct eb_transport* transport, struct eb_link* link) 
{
	dbgprint("Entering eb_lm32_udp_disconnect\n");
	//	ptpd_netif_close_socket
	dbgprint("Leavinging eb_lm32_udp_disconnect\n");

}

EB_PRIVATE void eb_lm32_udp_close(struct eb_transport* transport) 
{
	dbgprint("Entering eb_lm32_udp_close\n");
//	ptpd_netif_close_socket
	dbgprint("Leaving eb_lm32_udp_close\n");
}



// wont work without packet rule to route all udp/ip to LM32!
EB_PRIVATE int eb_lm32_udp_poll(struct eb_transport* transportp, struct eb_link* linkp, eb_user_data_t data, eb_descriptor_callback_t ready, uint8_t* buf, int len)
{
	dbgprint("Entering eb_lm32_udp_poll\n");
	
	struct eb_lm32_udp_link* link;
  	link = (struct eb_lm32_udp_link*)linkp;
	struct eb_lm32_udp_transport* transport;	
	
	transport = (struct eb_lm32_udp_transport*)transportp;
	
	uint8_t rx_buf[1500];
	dbgprint("Allocated 1500 byte rx buffer\n");
	uint16_t rx_len;
	
	if ((rx_len = ptpd_netif_recvfrom(transport->socket4, &saddr, rx_buf, sizeof(rx_buf), 0)) <= 0)
	return -1;
	dbgprint("rx_len is %d\n", rx_len);
	if(rx_len < len) return -1; //buffer too small for packet
	
	//validate dest mac address
	//uint8_t i;
	//bool mac_broadcast, macToMe;	
	//mac_broadcast = true;
	//for(i=0;i<6;i++) if(saddr.mac_dest[i] != 0xff) mac_broadcast=false;
	//macToMe = false;
	//for(i=0;i<6;i++) if(saddr.mac_dest[i] != link->mac[i]) macToMe=false;
	//if(!broadcast && !toMe) return -1;
	
	//validate ip/udp header:
	//if(ipv4_checksum((&rx_buf[0]), 12) != 0x0000) return -1; //ip checksum...
	//if(udp_checksum((&rx_buf[0]), (&rx_buf[UDP_END]), (rx_len-UDP_IP_HDR_LEN)) != 0x0000) return -1; //udp checksum
	//ipToMe = false;
	//for(i=0;i<4;i++) if(&buf[IP_DPA + i] != ) ipToMe=false;
	//if() return -1;//dest ip address...
	//if() return -1; //dest udp port

	
	//pass data, return data length
	memcpy(&buf, (&rx_buf[UDP_END]), (rx_len-UDP_IP_HDR_LEN));

	dbgprint("Entering eb_lm32_udp_poll\n");
	return (rx_len-UDP_IP_HDR_LEN);		
}



EB_PRIVATE void eb_lm32_udp_send(struct eb_transport* transportp, struct eb_link* linkp, const uint8_t* buf, int len)
{
	dbgprint("Entered eb_lm32_udp_send\n");	
	struct eb_lm32_udp_link* link;
	struct eb_lm32_udp_transport* transport;	
	uint8_t i;
	
	
	dbgprint("Data Buffer Content: \n");
	for (i=0;i<8; i++) dbgprint(" %2x", buf[i]);
	dbgprint("\n");

	transport = (struct eb_lm32_udp_transport*)transportp;
  	link = (struct eb_lm32_udp_link*)linkp;
	uint8_t tx_buf[1500];
	dbgprint("Allocated 1500 byte tx buffer\n");
	dbgprint("Found:\n");
	dbgprint("MAC:  %x:%x:%x:%x:%x:%x\n", 
		link->mac[0],link->mac[1],link->mac[2],link->mac[3],link->mac[4],link->mac[5]);
	
	//set target mac
	memcpy(saddr.mac, link->mac, 6);
	createUdpIpHdr(link, tx_buf, buf, len); 	//create UDP/IP header at the beginning of the tx buffer and returns ptr to end
	memcpy(&tx_buf[UDP_END], buf, len);				//copy data buffer into tx buffer

	dbgprint("Trying to send tx buffer\n");
	ptpd_netif_sendto(transport->socket4, &saddr, &tx_buf[0], (UDP_IP_HDR_LEN+len), 0); 
	dbgprint("Leaving eb_lm32_udp_send\n");
}


int eb_socket_run(eb_socket_t socket, int timeout_us) {return 0;}
EB_PRIVATE void eb_lm32_udp_send_buffer(struct eb_transport* transportp, struct eb_link* linkp, int on) {};
EB_PRIVATE void eb_lm32_udp_fdes(struct eb_transport* transportp, struct eb_link* link, eb_user_data_t data, eb_descriptor_callback_t cb) {};
EB_PRIVATE int eb_lm32_udp_recv(struct eb_transport* transportp, struct eb_link* linkp, uint8_t* buf, int len) {return 0;}
EB_PRIVATE int eb_lm32_udp_accept(struct eb_transport* transportp, struct eb_link* result_link, eb_user_data_t data, eb_descriptor_callback_t ready)  {return 0;}

static uint16_t myIP_checksum(uint8_t *buf, int shorts)
{
	int i;
	uint32_t sum;
	uint32_t tmp;
	

	dbgprint("ipchkskum: \n");
	sum = 0;
	for (i = 0; i < (shorts<<1); i+=2) {
		tmp =  (((uint32_t)buf[i])<<8) | ((uint32_t)buf[i+1]);		
		dbgprint("e %d %x\n", i, tmp);			
		sum += tmp;
	}
	//add carries to checksum
	sum = (sum >> 16) + (sum & 0xffff);
	//again in case this add had a carry	
	sum += (sum >> 16);
	//invert and truncate to 16 bit
	sum = (~sum & 0xffff);
	
	return (uint16_t)sum;
}



//Protocol header functions
static uint16_t udp_checksum(const uint8_t *hdrbuf, const uint8_t *databuf, uint16_t len)
{
	//Prep udp checksum	
	int i;
	uint32_t sum, pseudosum, tmp;

	sum = 0;
	pseudosum = 0;

	dbgprint("Len %4x\n", len);

	//calc chksum for data 
	for (i = 0; i < (len); i+=2)
	{
		tmp = ((uint32_t)(databuf[i+0]<<8)&0xFF00) | ((uint32_t)databuf[i+1]&0x00FF);
      sum += tmp;
   }
	if(len & 0x01) 	sum += (((uint32_t)databuf[i+1])<<8);// if len is odd, pad the last byte and add
	
	//add pseudoheader
	pseudosum +=  ((hdrbuf[IP_SPA+0]<<8)&0xFF00) | ((hdrbuf[IP_SPA+1])&0x00FF);
   pseudosum += ((hdrbuf[IP_SPA+2]<<8)&0xFF00) | ((hdrbuf[IP_SPA+3])&0x00FF);
   pseudosum += ((hdrbuf[IP_DPA+0]<<8)&0xFF00) | ((hdrbuf[IP_DPA+1])&0x00FF);
   pseudosum += ((hdrbuf[IP_DPA+2]<<8)&0xFF00) | ((hdrbuf[IP_DPA+3])&0x00FF);
   pseudosum += (hdrbuf[IP_PROTO] & 0x00FF);
   
   pseudosum += ((hdrbuf[UDP_SPP+0]<<8)&0xFF00) | ((hdrbuf[UDP_SPP+1])&0x00FF);
	pseudosum += ((hdrbuf[UDP_DPP+0]<<8)&0xFF00) | ((hdrbuf[UDP_DPP+1])&0x00FF);
	pseudosum += ((hdrbuf[UDP_LEN+0]<<8)&0xFF00) | ((hdrbuf[UDP_LEN+1])&0x00FF);
	pseudosum += ((hdrbuf[UDP_CHKSUM+0]<<8)&0xFF00) | (hdrbuf[UDP_CHKSUM+1]&0x00FF);
	
   sum += pseudosum + len + 8;
	
   //add carries and return complement
	sum = (sum >> 16) + (sum & 0xffff);
   sum += (sum >> 16);
	sum = (~sum & 0xffff);
	dbgprint("UDP inv %x\n", sum);
	return (uint16_t)sum;
}


static uint8_t* createUdpIpHdr(struct eb_lm32_udp_link* linkp, uint8_t* hdrbuf, const uint8_t* databuf, uint16_t len)
{
	dbgprint("entered udp/ip hdr creation\n");

	struct eb_lm32_udp_link* link;
  	link = (struct eb_lm32_udp_link*)linkp;
	uint16_t ipchksum, sum;
	uint16_t iptol, udplen;
	uint8_t i;
	
	iptol  = len + IP_HDR_LEN + UDP_HDR_LEN;
	udplen = len + UDP_HDR_LEN;

	// ------------- IP ------------
	hdrbuf[IP_VER_IHL]  	= 0x45;
	hdrbuf[IP_DSCP_ECN] 	= 0x00;
	hdrbuf[IP_TOL + 0]  	= (uint8_t)(iptol >> 8); //length after payload
	hdrbuf[IP_TOL + 1]  	= (uint8_t)(iptol & 0xff);
	hdrbuf[IP_ID + 0]  	= 0x00;
	hdrbuf[IP_ID + 1]  	= 0x00;
	hdrbuf[IP_FLG_FRG + 0]  = 0x00;
	hdrbuf[IP_FLG_FRG + 1]  = 0x00;	
	hdrbuf[IP_PROTO]	= 0x11; // UDP
	hdrbuf[IP_TTL]		= 0x10;
	hdrbuf[IP_CHKSUM + 0]  	= 0x00;
	hdrbuf[IP_CHKSUM + 1]	= 0x00;

	getIP(hdrbuf + IP_SPA);	//source IP
	memcpy(hdrbuf + IP_DPA, link->ipv4, 4); //dest IP
	
	ipchksum = myIP_checksum((&hdrbuf[0]), 10); //ip checksum
	hdrbuf[IP_CHKSUM + 0]  	= (uint8_t)(ipchksum >> 8);
	hdrbuf[IP_CHKSUM + 1]	= (uint8_t)(ipchksum);

	// ------------- UDP ------------
	dbgprint("IPV4: %x:%x:%x:%x\n", 
		link->ipv4[0],link->ipv4[1],link->ipv4[2],link->ipv4[3]);
	dbgprint("Port: %x\n", link->port);

	memcpy(hdrbuf + UDP_SPP, &myPort,2);
	memcpy(hdrbuf + UDP_DPP, &link->port, 2);
	hdrbuf[UDP_LEN + 0]  = (uint8_t)(udplen >> 8); //udp length after payload
	hdrbuf[UDP_LEN + 1]  = (uint8_t)(udplen);
	hdrbuf[UDP_CHKSUM + 0]  = 0x00;
	hdrbuf[UDP_CHKSUM + 1]  = 0x00;

	sum = udp_checksum(hdrbuf, databuf, len); //udp chksum
	hdrbuf[UDP_CHKSUM+0] = (uint8_t)(sum >> 8); 
	hdrbuf[UDP_CHKSUM+1] = (uint8_t)(sum);
	
	dbgprint("Header content: \n");
	for (i=0;i<UDP_END;i++) dbgprint(" %x", hdrbuf[i]);
	dbgprint("\n");


	dbgprint("leaving udp/ip hdr creation\n");	

	
	return hdrbuf;
}


//String helper functions
static char* strsplit(const char* numstr, const char* delimeter)
{
	char* pch = (char*)numstr;
	
	while (*(pch) != '\0') 
		if(*(pch++) == *delimeter) return pch;		
	
 	return pch;
}
 
static unsigned char* numStrToBytes(const char*  numstr, unsigned char* bytes,  unsigned char len,  unsigned char base, const char* delimeter)
{
	char * pch;
	char * pend;
	unsigned char byteCount=0;
	long tmpconv;	
	pch = (char *) numstr;

	while ((pch != NULL) && byteCount < len )
	{					
		pend = strsplit(pch, delimeter)-1;
		tmpconv = strtol((const char *)pch, &(pend), base);
		// in case of a 16 bit value		
		if(tmpconv > 255) 	bytes[byteCount++] = (unsigned char)(tmpconv>>8 & 0xff);
		bytes[byteCount++] = (unsigned char)(tmpconv & 0xff);					
		pch = pend+1;
	}
 	return bytes;
}

static  unsigned char* addressStrToBytes(const char* addressStr, unsigned char* addressBytes, adress_type_t addtype)
  {
	unsigned char len;
	unsigned char base;
	char del;
	
	if(addtype == MAC)		
	{
		len 	  =  6;
		base 	  = 16;
		del 	  = ':';
		
	}
	else if(addtype == IP)				 
	{
		len 	  =  4;
		base 	  = 10;
		del 	  = '.';
	}
	

	
	else{
	 return NULL;	
	}
	
	
	return numStrToBytes(addressStr, addressBytes, len, base, &del);
	
}
