/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __MINIC_H
#define __MINIC_H

#define ETH_HEADER_SIZE 14
#define ETH_ALEN 6
#define ETH_P_1588     0x88F7          /* IEEE 1588 Timesync */

#define WRPC_FID				0

#define WRF_DATA   0
#define WRF_OOB    1
#define WRF_STATUS 2
#define WRF_BYTESEL 3

#define TX_OOB 0x1000

/* Standard ethernet mac packet header. */
struct wr_ethhdr {
	uint8_t dstmac[6];
	uint8_t srcmac[6];
	uint16_t ethtype;
};

/* Ethernet mac packet header with VLAN. */
struct wr_ethhdr_vlan {
	uint8_t dstmac[6];
	uint8_t srcmac[6];
	uint16_t ethtype;
	uint16_t tag;
	uint16_t ethtype_2;
};

struct wr_minic {
    void *base;
    unsigned tx_count, rx_count, rx_errors;
};

struct hw_timestamp {
	uint8_t valid;
	int ahead;
	uint64_t sec;
	uint32_t nsec;
	uint32_t phase;
};

extern struct wr_minic minic;

void minic_init(struct wr_minic *nic, void *base);
void minic_disable(struct wr_minic *nic);
int minic_poll_rx(struct wr_minic *nic);
void minic_get_stats(struct wr_minic *nic, int *tx_frames, int *rx_frames, int*rx_errors);

int minic_rx_frame(struct wr_minic *nic, struct wr_ethhdr *hdr,
		   uint8_t *payload, uint32_t buf_size,
		   struct hw_timestamp *hwts);
int minic_tx_frame(struct wr_minic *nic, struct wr_ethhdr_vlan *hdr,
		   uint8_t *payload, uint32_t size,
		   struct hw_timestamp *hwts);

#endif
