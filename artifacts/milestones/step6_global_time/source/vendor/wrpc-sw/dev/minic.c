/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011,2012,2016 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <string.h>
#include <assert.h>
#include "wrc.h"
#include "wrpc.h"

#include "board.h"
#include "dev/pps_gen.h"		/* for pps_gen_get_time() */
#include "dev/minic.h"
#include "dev/syscon.h"

#include "hw/minic_regs.h"

#define MINIC_HDL_VERSION 1

#define F_COUNTER_BITS 4
#define F_COUNTER_MASK ((1<<F_COUNTER_BITS)-1)

#define RX_STATUS_ERROR(d) ((d) & (1<<1) ? 1 : 0)
#define RXOOB_TS_INCORRECT (1<<11)

#define RX_OOB_SIZE 3	/* as the number of FIFO data words */

// extracts the values of TS rising and falling edge counters from the descriptor header

#define EXPLODE_WR_TIMESTAMP(raw, rc, fc) \
  rc = (raw) & 0xfffffff;		  \
  fc = (raw >> 28) & 0xf;

//#define RX_DUMP

/* Exported for snmp.  */
struct wr_minic minic;

static unsigned char ver_supported;


static inline void minic_writel(struct wr_minic *nic, uint32_t reg, uint32_t data)
{
	*(volatile uint32_t *)(nic->base + reg) = data;
}

static inline uint32_t minic_readl(struct wr_minic *nic, uint32_t reg)
{
	return *(volatile uint32_t *)(nic->base + reg);
}

static inline void minic_txword(struct wr_minic *nic, int type, uint16_t word)
{
    minic_writel(nic, MINIC_REG_TX_FIFO,
		 MINIC_TX_FIFO_TYPE_W(type) | MINIC_TX_FIFO_DAT_W(word));
}

void minic_init(struct wr_minic *nic, void *base)
{
	uint32_t mcr;

	nic->base = base;

	/* before doing anything, check the HDL interface version */
	mcr = minic_readl(nic, MINIC_REG_MCR);
	if (MINIC_MCR_VER_R(mcr) != MINIC_HDL_VERSION) {
		pp_printf("Error: Minic HDL version %d not supported by sw\n",
			  (int) MINIC_MCR_VER_R(mcr));
		ver_supported = 0;
		return;
	}
	ver_supported = 1;

	/* disable interrupts, driver does polling */
	minic_writel(nic, MINIC_REG_EIC_IDR, MINIC_EIC_IDR_TX |
			MINIC_EIC_IDR_RX | MINIC_EIC_IDR_TXTS);

	/* enable RX path */
	minic_writel(nic, MINIC_REG_MCR, mcr | MINIC_MCR_RX_EN);
}

void minic_disable(struct wr_minic *nic)
{
	minic_writel(nic, MINIC_REG_MCR, 0);
}

int minic_poll_rx(struct wr_minic *nic)
{
	uint32_t mcr;

	if (!ver_supported)
		return 0;

	mcr = minic_readl(nic, MINIC_REG_MCR);

	return (mcr & MINIC_MCR_RX_EMPTY) ? 0 : 1;
}

int minic_rx_frame(struct wr_minic *nic, struct wr_ethhdr *hdr,
		   uint8_t *payload, uint32_t buf_size,
		   struct hw_timestamp *hwts)
{
	uint32_t hdr_size, payload_size;
	uint32_t raw_ts;
	int rx_empty, rx_type;
	uint16_t rx_data;
	uint16_t *ptr16_hdr, *ptr16_payload;
	uint32_t oob_cnt;
	uint16_t oob_hdr;
	uint64_t sec;
	uint32_t counter_r, counter_f, counter_ppsg;
	int cntr_diff;
	int got_rx_error = 0;

	if (!ver_supported)
		return 0;

	/* check if there is something in the Rx FIFO to be retrieved */
	if ((minic_readl(nic, MINIC_REG_MCR) & MINIC_MCR_RX_EMPTY))
		return 0;

	hdr_size = 0;
	payload_size = 0;
	/* uint16_t pointers to copy directly 16-bit data from FIFO to memory */
	ptr16_hdr = (uint16_t *)hdr;
	ptr16_payload = (uint16_t *)payload;
	/* Read the whole frame till OOB or till the FIFO is empty */
	oob_cnt = 0;
	raw_ts  = 0;
	oob_hdr = RXOOB_TS_INCORRECT;

#ifdef RX_DUMP
	pp_printf("RX@%x:", (unsigned)nic->base);
#endif

	while (1) {
		unsigned rx;

		rx = minic_readl(nic, MINIC_REG_RX_FIFO);
#ifdef RX_DUMP
		if ((rx >> 16) == 0)
			pp_printf(" %04x", rx);
		else
			pp_printf(" %08x", rx);
#endif
		rx_type = MINIC_RX_FIFO_TYPE_R(rx);
		rx_data = MINIC_RX_FIFO_DAT_R(rx);
		rx_empty = (rx & MINIC_RX_FIFO_EMPTY);

		if (rx_empty)
			break;

		if (rx_type == WRF_DATA && hdr_size < ETH_HEADER_SIZE) {
			/* reading header */
			ptr16_hdr[hdr_size>>1] = htons(rx_data);
			hdr_size += 2;
		} else if (rx_type != WRF_STATUS && payload_size > buf_size) {
			/* we've filled the whole buffer, in this case retreive
			 * remaining part of this frame (WRF_DATA or
			 * WRF_BYTESEL) but don't store it in the buffer */
			payload_size += 2;
		} else if (rx_type == WRF_DATA) {
			/* normal situation, retreiving payload */
			ptr16_payload[payload_size>>1] = htons(rx_data);
			payload_size += 2;
		} else if (rx_type == WRF_BYTESEL) {
			ptr16_payload[payload_size>>1] = htons(rx_data);
			payload_size += 1;
		} else if (rx_type == WRF_STATUS && hdr_size > 0) {
			/* receiving status means error in our frame or
			 * beginning of next frame. We check hdr_size > 0 to
			 * make sure it's not the first received word, i.e. our
			 * own initial status.*/
			//pp_printf("Rxstat %x\n", rx_data);
			if (RX_STATUS_ERROR(rx_data))
			{
				pp_printf("Warning: Minic @%x received erroneous "
					  "frame, %x\n", (unsigned)nic->base, rx);
				got_rx_error = 1;
			}

			break;


		} else if ( rx_type == WRF_OOB) {
			//pp_printf("rxoob\n");
			if (oob_cnt == 0)
				oob_hdr = rx_data;
			else if (oob_cnt == 1)
				raw_ts = (rx_data << 16) & 0xffff0000;
			else if (oob_cnt == 2)
				raw_ts |= (rx_data & 0x0000ffff);

			oob_cnt++;
		}
	}


#ifdef RX_DUMP
	pp_printf("\n");
#endif
	/* Receive OOB, if it's there */
	if (oob_cnt == 0 || oob_cnt > RX_OOB_SIZE) {
		/* in WRPC we expect every Rx frame to contain a valid OOB.
		 * If it's not the case, something went wrong... */
		net_verbose("Warning: got incorrect or missing Rx OOB\n");
		hwts->valid = 0;
	} else {
		/* build correct timestamp to return in hwts structure */
		shw_pps_gen_get_time(&sec, &counter_ppsg);

		EXPLODE_WR_TIMESTAMP(raw_ts, counter_r, counter_f);

		if (counter_r > 3 * REF_CLOCK_FREQ_HZ / 4
		    && counter_ppsg < 250000000)
			sec--;

		hwts->sec = sec;

		cntr_diff = (counter_r & F_COUNTER_MASK) - counter_f;

		if (cntr_diff == 1 || cntr_diff == (-F_COUNTER_MASK))
			hwts->ahead = 1;
		else
			hwts->ahead = 0;

		hwts->nsec = counter_r * (REF_CLOCK_PERIOD_PS / 1000);
		hwts->valid = (oob_hdr & RXOOB_TS_INCORRECT) ? 0 : 1;
	}

	/* Increment Rx counter for statistics */
	if( got_rx_error )
	{
		nic->rx_errors++;
		return -1;
	} else {
		nic->rx_count++;
	}

	if (minic_readl(nic, MINIC_REG_MCR) & MINIC_MCR_RX_FULL)
		pp_printf("Warning: Minic Rx fifo full, expect wrong frames\n");

	/* return number of bytes written to the *payload buffer */
	return (buf_size < payload_size ? buf_size : payload_size);
}

int minic_tx_frame(struct wr_minic *nic, struct wr_ethhdr_vlan *hdr,
		   uint8_t *payload, uint32_t size,
		   struct hw_timestamp *hwts)
{
	uint32_t mcr, pwords, hwords;
	int ts_valid;
	int i, hsize;
	uint16_t *ptr;

	if (!ver_supported)
		return 0;

	if (hdr->ethtype == htons(0x8100))
		hsize = sizeof(struct wr_ethhdr_vlan);
	else
		hsize = sizeof(struct wr_ethhdr);
	hwords = hsize >> 1;

	if (size + hsize < 60)
		size = 60 - hsize;
	pwords = size >> 1;

	/* First we write status word (empty status for Tx) */
	minic_txword(nic, WRF_STATUS, 0);

#ifdef TX_DUMP
	pp_printf("TX @%x:", (unsigned)nic->base);
#endif
	/* Write the header of the frame */
	ptr = (uint16_t *)hdr;
	for (i = 0; i < hwords; ++i) {
#ifdef TX_DUMP
		pp_printf(" %04x", htons(ptr[i]));
#endif
		minic_txword(nic, WRF_DATA, htons(ptr[i]));
	}

	/* Write the payload without the last word (which can be one byte) */
	ptr = (uint16_t *)payload;
	for (i = 0; i < pwords; ++i) {
#ifdef TX_DUMP
		pp_printf(" %04x", htons(ptr[i]));
#endif
		minic_txword(nic, WRF_DATA, htons(ptr[i]));
	}

	/* Write last word of the payload (which can be one byte) */
	if (size & 1)
		minic_txword(nic, WRF_BYTESEL, htons(ptr[i]));

#ifdef TX_DUMP
	pp_printf("\n");
#endif

	/* Write also OOB if needed */
	if (hwts) {
		minic_txword(nic, WRF_OOB, TX_OOB);
		minic_txword(nic, WRF_OOB, WRPC_FID);
	}

	/* Start sending the frame, and while we read mcr check for fifo full */
	mcr = minic_readl(nic, MINIC_REG_MCR);
	assert_warn((mcr & MINIC_MCR_TX_FULL) == 0, "Minic tx fifo full\n");
	minic_writel(nic, MINIC_REG_MCR, mcr | MINIC_MCR_TX_START);

	/* wait for the DMA to finish */
	for (i = 0; i < 1000; ++i) {
		mcr = minic_readl(nic, MINIC_REG_MCR);
		if ((mcr & MINIC_MCR_TX_IDLE) != 0) break;
		timer_delay_ms(1);
	}

	if (i == 1000)
		pp_printf("Warning: tx not terminated infinite mcr=0x%x\n",
			  (unsigned int) mcr);

	if (hwts) {
		uint32_t raw_ts;
		uint16_t fid;
		uint32_t counter_r, counter_f;
		uint64_t sec;
		uint32_t nsec;

		/* wait for the timestamp */
		for (i = 0; i < 100; ++i) {
			mcr = minic_readl(nic, MINIC_REG_MCR);
			if ((mcr & MINIC_MCR_TX_TS_READY) != 0) break;
			timer_delay_ms(1);
		}

		ts_valid = 1;

		if (i == 100)
		{
			pp_printf("Warning: tx timestamp never became available\n");
			ts_valid = 0;
		}


		if(ts_valid)
			ts_valid = minic_readl(nic, MINIC_REG_TSR0)
					     & MINIC_TSR0_VALID;

		raw_ts = minic_readl(nic, MINIC_REG_TSR1);
		fid = MINIC_TSR0_FID_R(minic_readl(nic, MINIC_REG_TSR0));

		if (fid != WRPC_FID) {
			wrc_verbose("minic_tx_frame: unmatched fid %d vs %d\n",
				  fid, WRPC_FID);
		}

		EXPLODE_WR_TIMESTAMP(raw_ts, counter_r, counter_f);
		(void) counter_f; /* Make a compiler happy */
		shw_pps_gen_get_time(&sec, &nsec);

		if (counter_r > 3 * REF_CLOCK_FREQ_HZ / 4 && nsec < 250000000)
			sec--;

		hwts->valid = ts_valid;
		hwts->sec = sec;
		hwts->ahead = 0;
		hwts->nsec = counter_r * (REF_CLOCK_PERIOD_PS / 1000);
		
		nic->tx_count++;
        }
        
	return size;
}

void minic_get_stats(struct wr_minic *nic, int *tx_frames, int *rx_frames, int *rx_errors)
{
	*tx_frames = nic->tx_count;
	*rx_frames = nic->rx_count;
	if(rx_errors)
		*rx_errors = nic->rx_errors;
}
