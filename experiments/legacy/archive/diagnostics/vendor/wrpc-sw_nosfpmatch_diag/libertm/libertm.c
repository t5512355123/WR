/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Copyright 2020-2021 CERN
 * Author: Juan David Gonzalez Cobas
 *
 * This library interacts with a simulated eRTM14/15 combo
 */

#include <limits.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <arpa/inet.h>
#include <math.h>

#include "libertm.h"
#include "private.h"
#include "psnmp-proto.h"
#include "board-aux.h"

static struct ertm_lib_version ertm_lib_versions = {
	.lib_version =	VERSION,
	.git_commit = GIT_VER,
	.git_user = GIT_USR,
	.git_url = GIT_URL,
};
static char __attribute__((__unused__)) *lib_internal_version =
	"internal_version=" GIT_VER ";" GIT_URL ";" VERSION;

struct ertm_error_codes ertm_error_codes[] = {
	[-ERTM_OK]		= { ERTM_OK, "success" },
	[-ERTM_BAD_CONNECTOR]	= { ERTM_BAD_CONNECTOR, "bad connector parameter" },
	[-ERTM_CH_OUT_OF_RANGE]	= { ERTM_CH_OUT_OF_RANGE, "channel number out of range" },
	[-ERTM_NOT_IMPLEMENTED]	= { ERTM_NOT_IMPLEMENTED, "function not implemented" },
	[-ERTM_UART_LINK_SEND_ERR] ={ ERTM_UART_LINK_SEND_ERR, "USB serial link send failed" },
	[-ERTM_UART_LINK_RECV_ERR] ={ ERTM_UART_LINK_RECV_ERR, "USB serial link recv failed" },
	[-ERTM_BAD_HANDLE	] = { ERTM_BAD_HANDLE, "invalid library handle in libertm call" },
	[-ERTM_BAD_OPCODE	] = { ERTM_BAD_OPCODE, "invalid opcode in UART protocol exchange" },
	[-ERTM_UART_PROTO_ERR	] = { ERTM_UART_PROTO_ERR, "UART protocol error" },
	[-ERTM_BAD_CLKAB_FREQ   ] = { ERTM_BAD_CLKAB_FREQ, "invalid CLKA/B frequency" },
	[-ERTM_BAD_CLKAB_FREQ   ] = { ERTM_BAD_CLKAB_FREQ, "invalid CLKA/B frequency" },
	[-ERTM_BAD_CLKAB_FREQ   ] = { ERTM_BAD_CLKAB_FREQ, "invalid CLKA/B frequency" },
	[-ERTM_BAD_SYNC_SOURCE	] = { ERTM_BAD_SYNC_SOURCE, "invalid sync source (must be one of NONE, PPS, RF_TRIGGER" },
};

char *ertm_perror(int error)
{
	return ertm_error_codes[-error].message;
}

struct ertm_sync_states ertm_sync_states[] = {
	[ERTM_SYNC_STATE_RESTART] = { ERTM_SYNC_STATE_RESTART,
		"rstr", "The output frequency or amplitude is changed by the user" },
	[ERTM_SYNC_STATE_WAIT_TIMING] = { ERTM_SYNC_STATE_WAIT_TIMING,
		"wtim", "The clock sync state machine is waiting for the WR timing to become available" },
	[ERTM_SYNC_STATE_CONFIGURE] = { ERTM_SYNC_STATE_CONFIGURE,
		"cfg", "The clock sync state machine is configuring the sync pulse generator" },
	[ERTM_SYNC_STATE_WAIT_TRIGGER] = { ERTM_SYNC_STATE_WAIT_TRIGGER,
		"wtrg", "The clock sync state machine is waiting for the sycn pulse to be triggered" },
	[ERTM_SYNC_STATE_READY] = { ERTM_SYNC_STATE_READY,
		"rdy", "Resync done, output clock is ready", },
};
const int ertm_n_sync_states = sizeof(ertm_sync_states)/sizeof(ertm_sync_states[0]);

int ertm_sync_state_translate(int sync_state, char **label, char **meaning)
{
	if (sync_state >= ertm_n_sync_states || sync_state < 0)
		return -EINVAL;
	*label   = ertm_sync_states[sync_state].label;
	*meaning = ertm_sync_states[sync_state].description;
	return 0;
}

/* translate enum to kHz if needed */
static uint32_t clkab_freq_table[] = {
	[ERTM_CLKAB_1000MHz] = 1000000000UL,
	[ERTM_CLKAB_500MHz]  =  500000000UL,
	[ERTM_CLKAB_250MHz]  =  250000000UL,
	[ERTM_CLKAB_125MHz]  =  125000000UL,
	[ERTM_CLKAB_62_5MHz] =   62500000UL,
};
const int clkab_nfreqs = sizeof(clkab_freq_table)/sizeof(clkab_freq_table[0]);

static void clkab_defaults(struct ertm14_board_state *bs)
{
	int i;
	bs->clka_enable_mask = 0;
	bs->clkb_enable_mask = 0;
	for (i = ERTM_CLKAB_MIN_CH; i <= ERTM_CLKAB_MAX_CH; i++) {
		bs->clka_freq_hz[i] = ERTM_CLKAB_DEFAULT_FREQ;
		bs->clkb_freq_hz[i] = ERTM_CLKAB_DEFAULT_FREQ;
	}
}

/* any sensible value will do, simulation-only stuff */
#define	ERTM_LOREF_DEFAULT_CHPOWER	15.0	/* dBm, random dflt */;

static void dds_defaults(struct ertm14_dds_state *lo_ref, uint32_t default_ftw)
{
	int i;

	memset(lo_ref, 0, sizeof(*lo_ref));
	lo_ref->ftw = default_ftw;
	for (i = ERTM_LOREF_MIN_CH; i <= ERTM_LOREF_MAX_CH; i++) {
		lo_ref->out_state[i] = ERTM_RF_OUT_OFF;
		lo_ref->out_power[i] = ERTM_LOREF_DEFAULT_CHPOWER;
	}
	lo_ref->ampl_factor = 0x7f;
	lo_ref->amp_power = ERTM_LOREF_DEFAULT_CHPOWER;
}

static struct ertm_temperatures temperatures_defaults = {
	50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50,
	{0, 0, 0, 0},
};

static struct ertm_voltages voltages_defaults = {
	11.9, 3.2, 1.0, 8.3, 8.3, 5.0, 11.95, 3.1,
	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, },
};
struct ertm_wr_status wr_status_default = {
	/* FIXME: copied, not #include'd, from wrc_diags_regs.h */
	/* eventually replace by struct wrc_diags */
	.VER = 0xdeadbabe,	   /* [0x0]: REG Version register */
	.CTRL = 0,			   /* [0x4]: REG Ctrl */
	.WDIAG_SSTAT = 0,	   /* [0x8]: REG WRPC Diag: servo status */
	.WDIAG_PSTAT = 1,	   /* [0xc]: REG WRPC Diag: Port status */
	.WDIAG_PTPSTAT = 3,	   /* [0x10]: REG WRPC Diag: PTP state */
	.WDIAG_ASTAT = 0xa5,   /* [0x14]: REG WRPC Diag: AUX state */
	.WDIAG_TXFCNT = 0xa5,  /* [0x18]: REG WRPC Diag: Tx PTP Frame cnts */
	.WDIAG_RXFCNT = 0xa5,  /* [0x1c]: REG WRPC Diag: Rx PTP Frame cnts */
	.WDIAG_SEC_MSB = 0xa5, /* [0x20]: REG WRPC Diag:local time [msb of s] */
	.WDIAG_SEC_LSB = 0xa5, /* [0x24]: REG WRPC Diag: local time [lsb of s] */
	.WDIAG_NS = 0xa5,	   /* [0x28]: REG WRPC Diag: local time [ns] */
	.WDIAG_MU_MSB = 0xa5,  /* [0x2c]: REG WRPC Diag: Round trip (mu) [msb of ps] */
	.WDIAG_MU_LSB = 0xa5,  /* [0x30]: REG WRPC Diag: Round trip (mu) [lsb of ps] */
	.WDIAG_DMS_MSB = 0xa5, /* [0x34]: REG WRPC Diag: Master-slave delay (dms) [msb of ps] */
	.WDIAG_DMS_LSB = 0xa5, /* [0x38]: REG WRPC Diag: Master-slave delay (dms) [lsb of ps] */
	.WDIAG_ASYM = 0xa5,	   /* [0x3c]: REG WRPC Diag: Total link asymmetry [ps] */
	.WDIAG_CKO = 0xa5,	   /* [0x40]: REG WRPC Diag: Clock offset (cko) [ps] */
	.WDIAG_SETP = 0xa5,	   /* [0x44]: REG WRPC Diag: Phase setpoint (setp) [ps] */
	.WDIAG_UCNT = 0xa5,	   /* [0x48]: REG WRPC Diag: Update counter (ucnt) */
	.WDIAG_TEMP = 0xa5,	   /* [0x4c]: REG WRPC Diag: Board temperature [C degree] */
	.WDIAG_AUX0_DETAIL_STAT = 0xa5,
	.WDIAG_AUX1_DETAIL_STAT = 0xa5,
	.WDIAG_AUX2_DETAIL_STAT = 0xa5,
	.WDIAG_AUX3_DETAIL_STAT = 0xa5,
	.WDIAG_RX_ERR_CNT = 0xa5,
	.WDIAG_SERVO_UPTIME_MSB = 0xa5,
	.WDIAG_SERVO_UPTIME_LSB = 0xa5,
	.WDIAG_SERVO_RESTART_COUNT = 0xa5,
	.WDIAG_BITSLIDE = 0xa5,
	.WDIAG_DELTA_RX_M = 0xa5,
	.WDIAG_DELTA_RX_S = 0xa5,
	.WDIAG_DELTA_TX_M = 0xa5,
	.WDIAG_DELTA_TX_S = 0xa5,
	.WDIAG_SPLL_HY = 0xa5,
	.WDIAG_SPLL_MY = 0xa5,
};

/* WARNING: mostly unused */
struct ertm_device_metadata device_metadata_defaults = {
	.vendor_id = 0x10dc,
	.device_id = 0xbabe,
	.version = 0xdeadbabe,
	.byte_order_mark = 0xFEFF,
	.source_id = "sim-ertm14/15",
	.capability_mask = 0,
	.vendor_uuid = { 0xad, 0x38, 0xb6, 0xb6, 0x86, 0x48,
			0x4a, 0x35, 0x98, 0x0e, 0xba, 0x93,
			0x75, 0xbd, 0x27, 0x61, },
};

/* All fake values to clearly spot simulation */
struct ertm_board_info board_info_defaults = {
	.ertm14_serial = "HCCFUDE000-0000666",
	.ertm15_serial = "HCCFUDF000-0000666",
	.ertm14_mac1 = 0x112233445566,
	.ertm14_mac2 = 0x223344556677,
        .wrpc_sw_commit_id =
		"8f087ad4e0aa8ede6736506bfdc1fbde",
        .wrpc_sw_build_date = "Mon Jan 25 2021",
        .wrpc_sw_build_time = "10:40:46 CET",
        .wrpc_sw_build_by = "dcobas@cern.ch",
	.ertm14_firmware_version = "5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a",
	.ertm15_firmware_version = "a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5a5",
	.firmware_metadata = {
		    .vendor_id = 0x10dc,
		    .device_id = 0xbabe,
		},
};

/* provide sensible initial values for all params */
static void ertm_status_init(struct ertm_state *st)
{
	struct ertm14_board_state *bs = &st->board_state;

	memcpy(&st->board_info, &board_info_defaults,
		sizeof(st->board_info));
	clkab_defaults(bs);
	dds_defaults(&bs->lo, ERTM_LO_DEFAULT_FREQ);
	dds_defaults(&bs->ref, ERTM_REF_DEFAULT_FREQ);
	bs->streamers_latency_cycles = ERTM14_NCO_RESET_DEFAULT_LATENCY;
	bs->streamers_timeout_cycles = ERTM14_NCO_RESET_DEFAULT_TIMEOUT;
	memcpy(&st->temperatures, &temperatures_defaults,
		sizeof(st->temperatures));
	memcpy(&st->voltages, &voltages_defaults,
		sizeof(st->voltages));
	memcpy(&st->wr_status, &wr_status_default, sizeof(st->wr_status));
	/* FIXME: st->nco_reset */
}

struct ertm_lib_version *ertm_lib_version(void)
{
	return &ertm_lib_versions;
}

/* constants of nature for this design */
static int serial_speed = 8*115200;

static int get_version_info(struct ertm_status *st,
			    struct ertm_board_info *bi);
struct ertm_status *ertm_init(const char *address)
{
	struct ertm_status *st = malloc(sizeof(*st));
	int err;

	if (st == NULL) {
		errno = ENOMEM;
		return NULL;
	}
	st->state = malloc(sizeof(*st->state));
	if (st->state == NULL) {
		free(st);
		errno = ENOMEM;
		return NULL;
	}
	if ((address == NULL) && ((address = ertm_find_usb_port()) == NULL)) {
		errno = ENODEV;
		return NULL;
	}

	strcpy(st->connection.serial_connection, address);
	err = uart_link_create_linux(&st->link, address, serial_speed);
	if (err != 0) {
		errno = ENODEV;
		return NULL;
	}
	/* this hardcodes using file lock-based mutexes. This protects
	 * the critical section from concurrent processes but NOT from
	 * concurrent threads. In case of thread contention, use
	 * ertm_semaphore_mutex, implemented in semph.c based on POSIX
	 * semaphores */
	st->mutex = ertm_flock_mutex;
	if (st->mutex->create(st) < 0) {
		errno = ENODEV;
		return NULL;
	}

	/* we init with fake values, then override with
	 * actual default hardware configs */
	ertm_status_init(st->state);
	get_version_info(st, &st->state->board_info);
	ertm_get_board_config(st, &st->state->board_state);
	clean_config(&st->state->next_state);
	clean_config(&st->state->commit_mask);
	st->state->mode = ERTM_IMMEDIATE;

	return st;
}

void ertm_exit(struct ertm_status *handle)
{
	if (handle != NULL)
		free(handle->state);
	free(handle);
}

int ertm_get_board_info(struct ertm_status *handle, struct ertm_board_info *info)
{
	if (handle == NULL) {
		errno = EINVAL;
		return -1;
	}
	memcpy(info, &handle->state->board_info, sizeof(*info));
	return 0;
}

static struct ertm_ch_range {
	int	min;
	int	max;
} ranges[] = {
	[ERTM_CLKA] = { ERTM_CLKAB_MIN_CH, ERTM_CLKAB_MAX_CH },
	[ERTM_CLKB] = { ERTM_CLKAB_MIN_CH, ERTM_CLKAB_MAX_CH },
	[ERTM_REF]  = { ERTM_LOREF_MIN_CH, ERTM_LOREF_MAX_CH },
	[ERTM_LO]   = { ERTM_LOREF_MIN_CH, ERTM_LOREF_MAX_CH },
};

/* sanity check connector/channel combinations */
static int out_of_range(enum ertm_connector connector, int channel)
{
	int min, max;

	switch (connector) {
	case ERTM_CLKA:
	case ERTM_CLKB:
	case ERTM_REF:
	case ERTM_LO:
		min = ranges[connector].min;
		max = ranges[connector].max;
		if ((channel < min) || (channel > max)) {
			errno = EINVAL;
			return ERTM_CH_OUT_OF_RANGE;
		}
		break;
	default:
		return ERTM_BAD_CONNECTOR;
		break;
	}
	return 0;
}

static int bad_handle(struct ertm_status *handle)
{
	if (handle == NULL) {
		errno = EINVAL;
		return -ERTM_BAD_HANDLE;
	}
	return 0;
}

static int bad_inputs(struct ertm_status *handle,
		enum ertm_connector connector, int channel)
{
	int err = 0;

	if ((err = bad_handle(handle)) != 0)
		return err;
	if ((err = out_of_range(connector, channel)) != 0)
		return err;
	return 0;
}

int ertm_proto_cycle_unlocked(struct ertm_status *st,
	int8_t opcode, void *payload, void *answer)
{
	int res = 0;
	struct uart_link *link = &st->link;
	struct uart_packet request, *tx_pkt = &request;
	struct uart_packet *r;
	struct ertm14_protocol_op *op = get_proto_op(opcode);

	if (op == NULL) {
		errno = EINVAL;
		return ERTM_BAD_OPCODE;
	}

	tx_pkt->ptype = ERTM14_UART_PTYPE_SNMP_REQ;
	tx_pkt->length = op->offset1 + op->length1;
	tx_pkt->payload[0] = op->opcode;
	if (op->length1 > 0)
	    memcpy(&tx_pkt->payload[op->offset1], payload, op->length1);
	res = uart_link_send(link, tx_pkt);
	if (res < 0) {
		fprintf(stderr, "error %d in uart_link_send\n", res);
		return ERTM_UART_LINK_SEND_ERR;
	}
	res = uart_link_recv(link, &r, 1000);
	if (res <= 0) {
		fprintf(stderr, "error (res %d) in uart_link_recv\n", res);
		errno = ECOMM;
		return ERTM_UART_LINK_RECV_ERR;
	}
	if (r->ptype != ERTM14_UART_PTYPE_SNMP_RESP) {
		fprintf(stderr, "error (bad packet type != RESP) in uart_link_recv\n");
		errno = EINVAL;
		return ERTM_UART_PROTO_ERR;
	}
	memset(answer, 0x5a, op->length2);
	memcpy(answer, &r->payload[op->offset2], op->length2);

	return 0;
}

/* all protocol cycle operations are locked, except set_board_config
 * and commit_board_config; this locked/unlocked frig is needed because
 * set_board_config/commit_board_config are not atomic in the wrc,
 * hence we make them atomic by making of their sequential call in
 * commit_config a critical section, instead of making ertm_proto_cycle
 * a single critical region, which would be ideal. Such is life
 */
int ertm_proto_cycle(struct ertm_status *st,
	int8_t opcode, void *payload, void *answer)
{
	int ret;

	st->mutex->acquire(st);
	ret = ertm_proto_cycle_unlocked(st, opcode, payload, answer);
	st->mutex->release(st);
	return ret;
}

void dds_to_host_order(struct ertm14_dds_state *dds, struct ertm14_dds_state *host)
{
	int i;

	host->ftw 		= ntohl(dds->ftw);
	host->amp_power 	= ntohl(dds->amp_power);
	host->ampl_factor 	= ntohl(dds->ampl_factor);
	host->sync_source 	= ntohl(dds->sync_source);
	host->sync_count 	= ntohl(dds->sync_count);
	host->sync_state	= dds->sync_state;
	for (i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++) {
		host->out_power[i] = ntohl(dds->out_power[i]);
		host->out_state[i] = dds->out_state[i];
	}
}

void dds_to_network_order(struct ertm14_dds_state *host, struct ertm14_dds_state *dds)
{
	int i;

	dds->ftw                 = htonl(host->ftw);
	dds->amp_power           = htonl(host->amp_power);
	dds->ampl_factor         = htonl(host->ampl_factor);
	dds->sync_source 	 = ntohl(host->sync_source);
	dds->sync_count 	 = ntohl(host->sync_count);
	dds->sync_state		 = host->sync_state;
	for (i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++) {
		dds->out_power[i] = htonl(host->out_power[i]);
		dds->out_state[i] = host->out_state[i];
	}
}

void board_state_to_network_order(struct ertm14_board_state *host, struct ertm14_board_state *board)
{
	int i;

	dds_to_network_order(&host->ref, &board->ref);
	dds_to_network_order(&host->lo,  &board->lo);
	board->clka_enable_mask = htonl(host->clka_enable_mask);
	board->clkb_enable_mask = htonl(host->clkb_enable_mask);
	board->streamers_latency_cycles = htonl(host->streamers_latency_cycles);
	board->streamers_timeout_cycles = htonl(host->streamers_timeout_cycles);
	for (i = ERTM_CLKAB_MIN_CH; i <= ERTM_CLKAB_MAX_CH; i++) {
		/* FIXME: not enum */
		board->clka_freq_hz[i] = htonl(host->clka_freq_hz[i]);
		board->clkb_freq_hz[i] = htonl(host->clkb_freq_hz[i]);
		board->clka_sync_state[i] = host->clka_sync_state[i];
		board->clkb_sync_state[i] = host->clkb_sync_state[i];
	}
}

void board_state_to_host_order(struct ertm14_board_state *board, struct ertm14_board_state *host)
{
	int i;

	dds_to_host_order(&board->ref, &host->ref);
	dds_to_host_order(&board->lo, &host->lo);
	host->clka_enable_mask = ntohl(board->clka_enable_mask);
	host->clkb_enable_mask = ntohl(board->clkb_enable_mask);
	host->streamers_latency_cycles = ntohl(board->streamers_latency_cycles);
	host->streamers_timeout_cycles = ntohl(board->streamers_timeout_cycles);
	for (i = ERTM_CLKAB_MIN_CH; i <= ERTM_CLKAB_MAX_CH; i++) {
		/* FIXME: not enum */
		host->clka_freq_hz[i] = ntohl(board->clka_freq_hz[i]);
		host->clkb_freq_hz[i] = ntohl(board->clkb_freq_hz[i]);
		host->clka_sync_state[i] = board->clka_sync_state[i];
		host->clkb_sync_state[i] = board->clkb_sync_state[i];
	}
}

static void diags_to_host(struct wrc_diags *diags, struct wrc_diags *host)
{
	int i;
	int ndiags = sizeof(*diags) / sizeof(uint32_t);
	uint32_t *src = (uint32_t *)diags;
	uint32_t *dst = (uint32_t *)host;

	for (i = 0; i < ndiags; i++)
		dst[i] = ntohl(src[i]);
}

static void streamer_diags_to_host(struct WR_STREAMERS_WB *diags, struct WR_STREAMERS_WB *host)
{
	int i;
	int ndiags = sizeof(*diags) / sizeof(uint32_t);
	uint32_t *src = (uint32_t *)diags;
	uint32_t *dst = (uint32_t *)host;

	for (i = 0; i < ndiags; i++)
		dst[i] = ntohl(src[i]);
}


/* here, bs **can** (and should) be st->state->board_state */
int ertm_get_board_config(struct ertm_status *st, struct ertm14_board_state *bs)
{
	struct ertm14_board_state b, *board = &b;
	int res;

	res = ertm_proto_cycle(st, ertm14_get_board_config, NULL, board);
	if (res < 0)
		return res;

	board_state_to_host_order(board, bs);
	return 0;
}

int ertm_get_wr_diags(struct ertm_status *st, struct wrc_diags *wrc_diags)
{
	int res;

	struct wrc_diags d, *diags = &d;

	res = ertm_proto_cycle(st, ertm14_get_wrc_diags, NULL, diags);
	if (res < 0)
		return res;
	diags_to_host(diags, wrc_diags);

	return 0;
}

int ertm_get_streamer_diags(struct ertm_status *st, struct WR_STREAMERS_WB *streamer_diags)
{
	int res;

	struct WR_STREAMERS_WB d, *diags = &d;

	res = ertm_proto_cycle(st, ertm14_get_streamers_diags, NULL, diags);
	if (res < 0)
		return res;

	streamer_diags_to_host(diags, streamer_diags);

	return 0;
}


void bytes_to_64_mac(uint64_t *mac, uint8_t src[])
{
	uint64_t tmp = 0;
	int i;

	for (i = 0; i < 6; i++) {
		tmp <<= 8;
		tmp |= src[i];
	}
	*mac = tmp;
}

void split_buildinfo(char *fpga, char *tag, char *date)
{
	char *p;
	char tmp[256];

	memcpy(tmp, fpga, 256);
	p = strtok(tmp, "\n");
	p = strtok(NULL, "\n");
	p = strtok(NULL, "\n");
	p = strtok(NULL, "\n");
	if (p == NULL) {
		*tag = *date = '\0';
		return;
	}
	strncpy(tag, p + strlen("tag:"), 16); tag[15] = '\0';
	p = strtok(NULL, "\n");
	p = strtok(NULL, "\n");
	if (p == NULL) {
		*date = '\0';
		return;
	}
	strncpy(date, p + strlen("syndate:"), 16); date[15] = '\0';
}

static int get_version_info(struct ertm_status *st,
			    struct ertm_board_info *bi)
{
	int res;
	char *fpga = bi->firmware_metadata.fpga_buildinfo_text;
	uint32_t *words = (uint32_t *)fpga;
	int size = sizeof(bi->firmware_metadata.fpga_buildinfo_text)/sizeof(uint32_t);
	int i;

	res = ertm_proto_cycle(st, ertm14_get_version_info, NULL, bi);
	/* FIXME: if they **really** want the MAC in uint64_t shape,
	 * here it is. I would prefer to have a uint8_t[8]
	 */
	bytes_to_64_mac(&bi->ertm14_mac1, bi->ertm14_mac1_bytes);
	bytes_to_64_mac(&bi->ertm14_mac2, bi->ertm14_mac2_bytes);
	bi->calibration_date = ntohl( bi->calibration_date );

	if (res < 0)
		return res;
	res = ertm_proto_cycle(st, ertm14_get_fpga_info, NULL, fpga);
	if (res < 0)
		return res;
	for (i = 0; i < size; i++)
		words[i] = ntohl(words[i]);
	split_buildinfo(fpga,
		(char *)bi->firmware_metadata.source_id,
		(char *)bi->firmware_metadata.vendor_uuid);
	return 0;
}

void sensors_to_host(struct proto_wrc_sensor *s, int nsensors)
{
	int i;
	for (i = 0; i < nsensors; i++)
		s[i].value = ntohs(s[i].value);
}

static inline double to_celsius(uint16_t value)
{
	return value/1.0;
}

static inline double to_volts(uint16_t value)
{
	return value/1000.0;
}

static inline double to_amps(uint16_t value)
{
	return value/1000.0;
}

/* FIXME: lifted from sensors.c - such is life */
static struct proto_wrc_sensor* wrc_sensor_find(
		struct proto_wrc_sensor *sensors,
		uint8_t id)
{
	struct proto_wrc_sensor *s = sensors;
	while (s->flags) {
		if( s->id == id )
			return s;
		s++;
	}
	return NULL;
}

int ertm_get_sensors(struct ertm_status *st,
	struct ertm_temperatures *t, struct ertm_voltages *v)
{
	int i, res;

	struct proto_wrc_sensor sensors[ERTM14_MAX_SENSORS_COUNT];
	struct proto_wrc_sensor *sensor;

	res = ertm_proto_cycle(st, ertm14_get_sensors, NULL, sensors);
	if (res < 0)
		return res;
	sensors_to_host(sensors, ERTM14_MAX_SENSORS_COUNT);

	for (i = 0; i < ertm_ntemperatures; i++) {
		int id = ertm_temperature_ids[i];
		double *temperatures = (double *)t;

		sensor = wrc_sensor_find(sensors, id);
		if (sensor && (sensor->flags & WRC_SENSOR_TEMP_CELSIUS)
				&& (sensor->flags & WRC_SENSOR_VALID))
			temperatures[i] = to_celsius(sensor->value);
		else
			temperatures[i] = ERTM_MINUS_INFINITY;
	}
	for (i = 0; i < ertm_nvoltages; i++) {
		int id = ertm_voltage_ids[i];
		double *voltages = (double *)v;

		sensor = wrc_sensor_find(sensors, id);
		if (sensor && (sensor->flags & WRC_SENSOR_VOLTAGE_MV)
				&& (sensor->flags & WRC_SENSOR_VALID))
			voltages[i] = to_volts(sensor->value);
		else
			voltages[i] = ERTM_MINUS_INFINITY;
	}
	sensor = wrc_sensor_find(sensors, ERTM15_CURRENT_OCXO);
	if (sensor && (sensor->flags & WRC_SENSOR_CURRENT_MA)
			&& (sensor->flags & WRC_SENSOR_VALID))
		v->ocxo_curr = to_amps(sensor->value);
	else
		v->ocxo_curr = ERTM_MINUS_INFINITY;
	return 0;
}

static int set_board_config(struct ertm_status *st,
			const struct ertm14_board_state *config)
{
	struct ertm14_board_state tmp, *bstmp = &tmp;

	copy_config(bstmp, config);
	bstmp->valid = 1;
	board_state_to_network_order(bstmp, bstmp);
	return ertm_proto_cycle_unlocked(st, ertm14_set_board_config, bstmp, NULL);
}

static int commit_board_config(struct ertm_status *st,
			struct ertm14_board_state *mask)
{
	struct ertm14_board_state tmp, *bstmp = &tmp;

	copy_config(bstmp, mask);
	board_state_to_network_order(bstmp, bstmp);
	return ertm_proto_cycle_unlocked(st, ertm14_commit_board_config, bstmp, NULL);
}

static void update_board_config(struct ertm_status *st,
			struct ertm14_board_state *bs)
{
	/* call this sparingly; for the time being, let's do it in
	 * immediate mode */
	ertm_get_board_config(st, bs);
}

static int ertm_get_freq_sync_out_state(struct ertm_status *handle,
		enum ertm_connector connector, int channel,
		uint32_t *freq, int *sync_state, uint8_t *out_state)
{
	int err = 0;
	struct ertm14_board_state *bs;
	uint32_t *freg;
	uint8_t *ssreg;
	int enable;

	if ((err = bad_inputs(handle, connector, channel)) != 0)
		return err;

	bs = &handle->state->board_state;
	switch (connector) {
	case ERTM_CLKA:
		freg  = &bs->clka_freq_hz[channel];
		ssreg = &bs->clka_sync_state[channel];
		enable = !!(bs->clka_enable_mask & (1<<channel));
		// clkab_set_output_divider(ERTM14_OUT_CLKA, channel, freq);
		break;
	case ERTM_CLKB:
		freg  = &bs->clkb_freq_hz[channel];
		ssreg = &bs->clkb_sync_state[channel];
		enable = !!(bs->clkb_enable_mask & (1<<channel));
		break;
	case ERTM_LO:
		freg  = &bs->lo.ftw;
		ssreg = &bs->lo.sync_state;
		enable = bs->lo.out_state[channel] != ERTM15_RF_OUT_OFF;
		break;
	case ERTM_REF:
		freg  = &bs->ref.ftw;
		ssreg = &bs->ref.sync_state;
		enable = bs->ref.out_state[channel] != ERTM15_RF_OUT_OFF;
		break;
	default:
		errno = EINVAL;
		return ERTM_BAD_CONNECTOR;
	}
	update_board_config(handle, &handle->state->board_state);
	*freq = *freg;
	*sync_state = *ssreg;
	*out_state = enable;

	return 0;
}

int ertm_get_freq(struct ertm_status *handle,
		enum ertm_connector connector, int channel, uint32_t *freq)
{
	uint32_t u;
	void *unused1 = &u, *unused2 = &u;

	/* channel param is irrelevant for lo/ref freq */
	if (connector == ERTM_LO || connector == ERTM_REF) {
		channel = ERTM_LOREF_MIN_CH;
	}
	return ertm_get_freq_sync_out_state(handle, connector, channel,
					freq, unused1, unused2);
}

int ertm_get_sync_state(struct ertm_status *handle,
		enum ertm_connector connector, int channel, int *sync_state)
{
	uint32_t u;
	void *unused1 = &u, *unused2 = &u;

	/* channel param is irrelevant for lo/ref sync state */
	if (connector == ERTM_LO || connector == ERTM_REF) {
		channel = ERTM_LOREF_MIN_CH;
	}
	return  ertm_get_freq_sync_out_state(handle, connector, channel,
					unused1, sync_state, unused2);
	return 0;
}

int ertm_get_enable_state(struct ertm_status *handle,
		enum ertm_connector connector, int channel, uint8_t *enable_state)
{
	uint32_t u;
	void *unused1 = &u, *unused2 = &u;
	return ertm_get_freq_sync_out_state(handle, connector, channel,
					unused1, unused2, enable_state);
	return 0;
}

static void commit_config(struct ertm_status *handle,
				struct ertm14_board_state *next,
				struct ertm14_board_state *mask)
{
	struct ertm14_board_state *bs = &handle->state->board_state;
	switch (handle->state->mode) {
	case ERTM_DEFERRED:
		break;
	case ERTM_SIMULATED:
		update_config(bs, next, mask);
		clean_config(next);
		clean_config(mask);
		break;
	case ERTM_IMMEDIATE:
		update_config(bs, next, mask);
		handle->mutex->acquire(handle);
		set_board_config(handle, next);
		commit_board_config(handle, mask);
		handle->mutex->release(handle);
		clean_config(next);
		clean_config(mask);
		break;
	case ERTM_OPTIMIZED:
		/* all done through immediate calls (when implemented) */
		break;
	}
}

static int valid_clkab_freq(uint32_t freq)
{
	int i;

	for (i = 0; i < clkab_nfreqs; i++)
		if (clkab_freq_table[i] == freq)
			return 1;
	return 0;
}

int ertm_set_freq(struct ertm_status *handle,
		enum ertm_connector connector,int channel, uint32_t freq)
{
	int err = 0;
	struct ertm14_board_state *next, *mask;

	/* channel param is irrelevant for lo/ref */
	if (connector == ERTM_LO || connector == ERTM_REF) {
		channel = ERTM_LOREF_MIN_CH;
	}
	if ((err = bad_inputs(handle, connector, channel)) != 0)
		return err;
	if (connector == ERTM_CLKA || connector == ERTM_CLKB) {
		if (!valid_clkab_freq(freq)) {
			errno = EINVAL;
			return ERTM_BAD_CLKAB_FREQ;
		}
	}
	next = &handle->state->next_state;
	mask = &handle->state->commit_mask;
	switch (connector) {
	case ERTM_CLKA:
		next->clka_freq_hz[channel] = freq;
		mask->clka_freq_hz[channel] = 1;
		// clkab_set_output_divider(ERTM14_OUT_CLKA, channel, freq);
		break;
	case ERTM_CLKB:
		next->clkb_freq_hz[channel] = freq;
		mask->clkb_freq_hz[channel] = 1;
		break;
	case ERTM_LO:
		next->lo.ftw = freq;
		mask->lo.ftw = 1;
		break;
	case ERTM_REF:
		next->ref.ftw = freq;
		mask->ref.ftw = 1;
		break;
	default:
		errno = EINVAL;
		return ERTM_BAD_CONNECTOR;
	}
	if (handle->state->mode == ERTM_IMMEDIATE)
		commit_config(handle, next, mask);
	return 0;
}

static void set_bit(uint32_t *word, unsigned bit, int value)
{
	value = ((!!value) << bit);
	*word &= ~(1<<bit);
	*word |= value;
}

int ertm_channel_enable(struct ertm_status *handle,
		enum ertm_connector connector, int channel, int enable)
{
	struct ertm14_board_state *next;
	struct ertm14_board_state *mask;
	int err;

	if ((err = bad_inputs(handle, connector, channel)) != 0) {
		return err;
	}

	next = &handle->state->next_state;
	mask = &handle->state->commit_mask;
	switch (connector) {
	case ERTM_CLKA:
		set_bit(&next->clka_enable_mask, channel, enable);
		set_bit(&mask->clka_enable_mask, channel, 1);
		break;
	case ERTM_CLKB:
		set_bit(&next->clkb_enable_mask, channel, enable);
		set_bit(&mask->clkb_enable_mask, channel, 1);
		//clkab_enable_output(ERTM14_OUT_CLKA, channel, enable);
		break;
	case ERTM_LO:
		next->lo.out_state[channel] =
			(enable ? ERTM_RF_OUT_ON : ERTM_RF_OUT_OFF);
		mask->lo.out_state[channel] = 1;
		break;
	case ERTM_REF:
		next->ref.out_state[channel] =
			(enable ? ERTM_RF_OUT_ON : ERTM_RF_OUT_OFF);
		mask->ref.out_state[channel] = 1;
		break;
	default:
		errno = EINVAL;
		return ERTM_BAD_CONNECTOR;
	}

	if (handle->state->mode == ERTM_IMMEDIATE)
		commit_config(handle, next, mask);
	return 0;
}

static int get_dds(struct ertm14_board_state *bs,
		enum ertm_connector connector, struct ertm14_dds_state **dds)
{
	switch (connector) {
	case ERTM_LO:
		*dds = &bs->lo;
		break;
	case ERTM_REF:
		*dds = &bs->ref;
		break;
	default:
		return ERTM_BAD_CONNECTOR;
		break;
	}
	return 0;
}

struct ertm14_board_state *get_board_state(struct ertm_status *st)
{
	struct ertm14_board_state *bs = NULL;

	if (st != NULL && st->state != NULL)
		bs = &st->state->board_state;
	return bs;
}

static int32_t signext32( uint32_t in, int bit )
{
	uint32_t mask = ~ ((1<<bit)-1);
	printf("MASK %x\n", mask);
	if( in & (1<<bit) )
		return in | mask;
	else
		return in;
}

static double amp_power_to_dBm(uint32_t amp_power)
{
	/* register values are in mBm, *not* mdBm;
	 * hence the *10/1000.0 factor */
	return (signext32( amp_power & 0x7fffffff, 30 ) ) / 100.0;
}

int ertm_get_power(struct ertm_status *handle,
		enum ertm_connector connector, double *power)
{
	struct ertm14_dds_state *dds;
	struct ertm14_board_state *bs;
	int err;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	if ((err = get_dds(bs, connector, &dds)) != 0) {
		errno = EINVAL;
		return err;
	}

	update_board_config(handle, bs);

	if( !( dds->amp_power & ERTM_FLAGS_DDS_POWER_VALID_MASK ) )
		return -EBUSY;

	*power = amp_power_to_dBm(dds->amp_power);
	return 0;
}

int ertm_get_channel_power(struct ertm_status *handle,
		enum ertm_connector connector, int channel, double *power)
{
	double pws[ERTM_LOREF_MAX_CH];
	int res;
	uint32_t mask = (1<<channel);

	if (bad_inputs(handle, connector, channel) ||
		(connector != ERTM_LO && connector != ERTM_REF)) {
		errno = EINVAL;
		return ERTM_CH_OUT_OF_RANGE;
	}
	res = ertm_get_channel_power_all(handle,
		connector, mask, pws);
	if (res < 0)
		return res;
	*power = pws[channel];
	return 0;
}

int ertm_get_channel_power_all(struct ertm_status *handle,
		enum ertm_connector connector,
		uint32_t valid_mask, double *power)
{
	struct ertm14_dds_state *dds;
	struct ertm14_board_state *bs;
	int i, err;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	if ((err = get_dds(bs, connector, &dds)) != 0) {
		errno = EINVAL;
		return err;
	}
	update_board_config(handle, bs);
	for (i = ERTM_LOREF_MIN_CH; i <= ERTM_LOREF_MAX_CH; i++) {
		if (valid_mask & (1<<i))
		{
			if( ! (dds->out_power[i] & ERTM_FLAGS_DDS_POWER_VALID_MASK) )
				return -EBUSY;
		    power[i] = amp_power_to_dBm(dds->out_power[i]);
	}
	}
	return 0;
}

static double ampl_factor_to_float(uint8_t ampl_factor)
{
	return ampl_factor/256.0;
}

static uint8_t float_to_ampl_factor(double level)
{
	return (uint8_t)floor(level * 256);
}

int ertm_dds_set_level_adjust(struct ertm_status *handle,
		enum ertm_connector connector, double level)
{
	struct ertm14_dds_state *dds, *ddsmask;
	struct ertm14_board_state *bs;
	struct ertm14_board_state *next;
	struct ertm14_board_state *mask;
	int err;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	if ((err = get_dds(bs, connector, &dds)) != 0) {
		errno = EINVAL;
		return err;
	}

	next = &handle->state->next_state;
	mask = &handle->state->commit_mask;
	get_dds(next, connector, &dds);
	get_dds(mask, connector, &ddsmask);
	dds->ampl_factor = float_to_ampl_factor(level);
	ddsmask->ampl_factor = 1;

	if (handle->state->mode == ERTM_IMMEDIATE)
		commit_config(handle, next, mask);

	return 0;
}

int ertm_dds_get_level_adjust(struct ertm_status *handle,
		enum ertm_connector connector, double *level)
{
	struct ertm14_board_state *bs;
	struct ertm14_dds_state *dds;
	int err;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	if ((err = get_dds(bs, connector, &dds)) != 0)
		return err;

	*level = ampl_factor_to_float(dds->ampl_factor);
	return 0;
}

int ertm_get_temperatures(struct ertm_status *handle, struct ertm_temperatures *temps)
{
	int res;

	res = ertm_get_sensors(handle, &handle->state->temperatures, &handle->state->voltages);
	if (res < 0)
		return res;
	memcpy(temps, &handle->state->temperatures, sizeof(*temps));
	return 0;
}

int ertm_get_voltages(struct ertm_status *handle, struct ertm_voltages *volts)
{
	int res;

	res = ertm_get_sensors(handle, &handle->state->temperatures, &handle->state->voltages);
	if (res < 0)
		return res;
	/* FIXME: if vdiv is screwed up in PCB, we'll need this.
	 * To be determined
	handle->state->voltages.p12v_ertm15 /= 2.0;
	 */
	memcpy(volts, &handle->state->voltages, sizeof(*volts));
	return 0;
}

int ertm_get_ocxo_current(struct ertm_status *handle, double *current)
{
	int res;

	res = ertm_get_sensors(handle, &handle->state->temperatures, &handle->state->voltages);
	if (res < 0)
		return res;
	*current = handle->state->voltages.ocxo_curr;
	return 0;
}

/* system-wide NCO reset */
void nco_to_host_order(struct ertm_nco_reset *nco)
{
	nco->enabled		= ntohl(nco->enabled);
	nco->sync_source	= ntohl(nco->sync_source);
	nco->current_stream_id	= ntohl(nco->current_stream_id);
	nco->rx_count		= ntohl(nco->rx_count);
	nco->reset_count	= ntohl(nco->reset_count);
	nco->connector		= ntohl(nco->connector);
};

void nco_to_network_order(struct ertm_nco_reset *nco)
{
	nco->enabled		= htonl(nco->enabled);
	nco->sync_source	= htonl(nco->sync_source);
	nco->current_stream_id	= htonl(nco->current_stream_id);
	nco->rx_count		= htonl(nco->rx_count);
	nco->reset_count	= htonl(nco->reset_count);
	nco->connector		= htonl(nco->connector);
};

int ertm_nco_reset_get_status(struct ertm_status *handle, struct ertm_nco_reset status[])
{
	struct ertm14_board_state *bs = &handle->state->board_state;
	int res;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	res = ertm_proto_cycle(handle, ertm14_get_wrc_nco, NULL, status);
	if (res < 0)
		return res;
	nco_to_host_order(&status[0]);
	nco_to_host_order(&status[1]);
	return 0;
}

int ertm_nco_reset_subscribe(struct ertm_status *handle,
		enum ertm_connector connector, int mode, int channel, uint32_t stream_id)
{
	struct ertm14_board_state *bs = &handle->state->board_state;
	struct ertm14_dds_state *dds;
	struct ertm_nco_reset tmp, *nco_subscription = &tmp;
	int res;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	if ((res = get_dds(bs, connector, &dds)) != 0)
		return res;
	if (!((mode == ERTM14_SYNC_SOURCE_NONE) ||
		(mode == ERTM14_SYNC_SOURCE_RF_TRIGGER) ||
		(mode == ERTM14_SYNC_SOURCE_PPS))) {
			errno = -EINVAL;
			return ERTM_BAD_SYNC_SOURCE;
	}

	/* need DDS LO/REF; type of sync; and reset the counter */
	/* channel does not play any role here, nor stream (yet) */
	nco_subscription->sync_source = mode;
	nco_subscription->connector = (connector == ERTM_LO) ?
		ERTM14_DDS_SYNC_LO : ERTM14_DDS_SYNC_REF;
	nco_subscription->reset_count = 0;
	nco_subscription->current_stream_id = stream_id = 0;
		/* remove this when several streams exist */
	nco_to_network_order(nco_subscription);
	res = ertm_proto_cycle(handle, ertm14_subscribe_nco, nco_subscription, NULL);
	if (res < 0)
		return res;
	return 0;
}

/* FIXME: this has no place in the current ertm implementation,
 * suppress if possible */
int ertm_rf_nco_reset(struct ertm_status *handle)
{
	return ERTM_NOT_IMPLEMENTED;
}
/* FIXME: this has no place in the current ertm implementation,
 * suppress if possible */
int ertm_rf_nco_reset_enable(struct ertm_status *handle, int enable)
{
	return ERTM_NOT_IMPLEMENTED;
}

int ertm_wr_diags(struct ertm_status *handle, struct ertm_wr_status *status)
{
	struct wrc_diags *s = (struct wrc_diags *)status;
	return ertm_get_wr_diags(handle, s);
}

int ertm_streamer_diags(struct ertm_status *handle, struct ertm_streamer_status *status)
{
	struct WR_STREAMERS_WB *s = (struct WR_STREAMERS_WB *)status;
	return ertm_get_streamer_diags(handle, s);
}

int ertm_reset_streamer_diags(struct ertm_status *handle )
{
	if (bad_handle(handle))
		return -ERTM_BAD_HANDLE;

	/* do a call to ptp start/stop */
	int dummy;

	return ertm_proto_cycle(handle, ertm14_reset_streamers_stats, &dummy, NULL);
}

int ertm_wr_status(struct ertm_status *handle, int *link_up, int *is_locked)
{
	struct ertm_wr_status status;
	int err;

	if ((err = ertm_wr_diags(handle, &status)) != 0)
		return err;
	*link_up = status.WDIAG_PSTAT & 1;
	*is_locked = status.WDIAG_PSTAT & 2;

	return 0;
}

int ertm_wr_enable(struct ertm_status *handle, int mode)
{
	uint8_t e = mode;

	if (bad_handle(handle))
		return -ERTM_BAD_HANDLE;

	/* do a call to ptp start/stop */
	handle->state->ptp_enabled = e;
	return ertm_proto_cycle(handle, ertm14_ptp_enable, &e, NULL);
}

/* streamer latency and timeout getter/setters */
static int ertm_set_streamers_latency_timeout(struct ertm_status *handle, uint32_t cycles16n, int is_latency)
{
	struct ertm14_board_state *bs, *next, *mask;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	next = &handle->state->next_state;
	mask = &handle->state->commit_mask;

	if (is_latency) {
	    next->streamers_latency_cycles = cycles16n;
	    mask->streamers_latency_cycles = 1;
	} else {
	    next->streamers_timeout_cycles = cycles16n;
	    mask->streamers_timeout_cycles = 1;
	}

	if (handle->state->mode == ERTM_IMMEDIATE)
		commit_config(handle, next, mask);
	return 0;
}

int ertm_set_streamers_latency(struct ertm_status *handle, uint32_t cycles16n)
{
	return ertm_set_streamers_latency_timeout(handle, cycles16n, 1);
}

int ertm_set_streamers_timeout(struct ertm_status *handle, uint32_t cycles16n)
{
	return ertm_set_streamers_latency_timeout(handle, cycles16n, 0);
}

int ertm_get_streamers_latency_timeout(struct ertm_status *handle,
	    uint32_t *latency_cycles, uint32_t *timeout_cycles)
{
	struct ertm14_board_state *bs;

	if ((bs = get_board_state(handle)) == NULL) {
		errno = EINVAL;
		return ERTM_BAD_HANDLE;
	}
	/* it is correct to assume that these
	 * are in sync with HW-read values */
	*latency_cycles = bs->streamers_latency_cycles;
	*timeout_cycles = bs->streamers_timeout_cycles;
	return 0;
}

int ertm_force_measure_channels_power( struct ertm_status *handle )
{
	if (bad_handle(handle))
		return -ERTM_BAD_HANDLE;

	/* do a call to ptp start/stop */
	int dummy;

	return ertm_proto_cycle(handle, ertm14_force_measure_channels_power, &dummy, NULL);
}

int ertm_configure_spll_debug_dump(struct ertm_status *handle, int enabled, int undersample)
{
	struct ertm14_spll_debug_dump_request request;
	
	request.enabled = htonl(enabled);
	request.undersample = htonl(undersample);

	int res = ertm_proto_cycle(handle, ertm14_configure_spll_debug_dump, &request, NULL);
	if (res < 0)
		return res;

	return 0;
}

int ertm_execute_shell_command(struct ertm_status *handle, char *cmd)
{
	struct ertm14_shell_command request;
	
	strncpy( request.cmd, cmd, 64 );

	int res = ertm_proto_cycle(handle, ertm14_exec_shell_command, &request, NULL);
	if (res < 0)
		return res;

	return 0;
}


int ertm_read_spll_debug_data( struct ertm_status *handle, uint32_t *buf, size_t *buf_size )
{
	int res = 0, i;
	struct uart_link *link = &handle->link;
	struct uart_packet *pkt;
	struct ertm14_spll_debug_dump_data *dbgdata;

	res = uart_link_recv(link, &pkt, 1000);

	if( res < 0 )
		return res;

	if (pkt->ptype != ERTM14_UART_PTYPE_SOFTPLL_LOG) {
		fprintf(stderr, "error (bad packet type != RESP) in uart_link_recv [got %d exp %d]\n", pkt->ptype, ERTM14_UART_PTYPE_SOFTPLL_LOG);
		errno = EINVAL;
		return ERTM_UART_PROTO_ERR;
	}

	if( !buf_size )
	{
		errno = EINVAL;
		return ERTM_UART_PROTO_ERR;
	}

	if( *buf_size < pkt->length )
	{
		errno = ENOSPC;
		return ERTM_UART_PROTO_ERR;
	}

	dbgdata = (void *)&pkt->payload;
	dbgdata->flags = ntohl( dbgdata->flags );
	int cnt = pkt->length / sizeof(uint32_t) - 1;

	if( cnt <= 0 )
		return ERTM_UART_PROTO_ERR;

	if( (dbgdata->flags & 0xffff) != ERTM14_SPLL_DEBUG_DUMP_HEADER )
	{
		errno = EINVAL;
		return ERTM_UART_PROTO_ERR;
	}

//	printf("cnt %d res %d plen %d flags %08x\n", cnt, res, pkt->length, dbgdata->flags );

	for(i = 0; i < cnt; i++ )
		dbgdata->payload[i] = ntohl( dbgdata->payload[i] );


	memcpy( buf, dbgdata->payload, cnt * sizeof(uint32_t) );

	*buf_size = cnt;

	if( dbgdata->flags & ERTM14_SPLL_DEBUG_DUMP_OVERFLOW )
		return ERTM_SPLL_LOG_OVERFLOW;

	return 0;
}
