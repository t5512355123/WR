/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Copyright 2020-2021 CERN
 * Author: Juan David Gonzalez Cobas
 *
 * This library interacts with a simulated eRTM14/15 combo
 */

#ifndef _LIBERTM_H_
#define _LIBERTM_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stdio.h>

#include "ertm-common.h"
#include "hw/wrc_diags_regs.h"

struct ertm_lib_version {
	char *lib_version;
	char *git_commit;
	char *git_user;
	char *git_url;
};

/* error codes */
#define ERTM_OK		0
#define ERTM_BAD_CONNECTOR	(-1)
#define ERTM_CH_OUT_OF_RANGE	(-2)
#define ERTM_NOT_IMPLEMENTED	(-3)
#define ERTM_UART_LINK_SEND_ERR (-4)
#define ERTM_UART_LINK_RECV_ERR (-5)
#define ERTM_BAD_HANDLE		(-6)
#define ERTM_BAD_OPCODE		(-7)
#define	ERTM_UART_PROTO_ERR	(-8)
#define	ERTM_BAD_CLKAB_FREQ	(-9)
#define	ERTM_BAD_SYNC_SOURCE	(-10)
#define ERTM_SPLL_LOG_OVERFLOW (-11)

struct ertm_error_codes {
	int	code;
	char	*message;
};

extern struct ertm_error_codes ertm_error_codes[];

extern char *ertm_perror(int error);

/* board constant of nature definitions */
enum ertm_clkab_freq {
	ERTM_CLKAB_1000MHz,
	ERTM_CLKAB_500MHz,
	ERTM_CLKAB_250MHz,
	ERTM_CLKAB_125MHz,
	ERTM_CLKAB_62_5MHz,
};

enum ertm_connector {
	ERTM_CLKA,
	ERTM_CLKB,
	ERTM_LO,
	ERTM_REF,
};

/* MONITOR is OFF to all effects and purposes */
#define	ERTM_RF_OUT_ON		ERTM_COMMON_RF_OUT_ON
#define	ERTM_RF_OUT_OFF		ERTM_COMMON_RF_OUT_OFF
#define	ERTM_RF_OUT_MONITOR	ERTM_COMMON_RF_OUT_MONITOR

/* real available channels in connectors */
#define ERTM_CLKAB_MIN_CH	ERTM_COMMON_CLKAB_OUT_MIN_ID
#define ERTM_CLKAB_MAX_CH	ERTM_COMMON_CLKAB_OUT_MAX_ID
#define ERTM_LOREF_MIN_CH	ERTM_COMMON_RF_OUT_MIN_ID
#define ERTM_LOREF_MAX_CH	ERTM_COMMON_RF_OUT_MAX_ID

/* front panel LEMO connector is actually the last channel (number 15)
 * available in the CLKA/B connector
 */
#define ERTM14_CLKAB_OUT_FRONT_PANEL	ERTM_COMMON_CLKAB_OUT_FRONT_PANEL

/* sync states of DDS and CLKA/B channels */

#define	ERTM_SYNC_STATE_RESTART      ERTM_COMMON_CLK_SYNC_STATE_RESTART
#define	ERTM_SYNC_STATE_WAIT_TIMING  ERTM_COMMON_CLK_SYNC_STATE_WAIT_TIMING
#define	ERTM_SYNC_STATE_CONFIGURE    ERTM_COMMON_CLK_SYNC_STATE_CONFIGURE
#define	ERTM_SYNC_STATE_WAIT_TRIGGER ERTM_COMMON_CLK_SYNC_STATE_WAIT_TRIGGER
#define	ERTM_SYNC_STATE_READY        ERTM_COMMON_CLK_SYNC_STATE_READY

/* sync modes */
#define ERTM_SYNC_SOURCE_NONE		ERTM_COMMON_SYNC_SOURCE_NONE
#define ERTM_SYNC_SOURCE_PPS		ERTM_COMMON_SYNC_SOURCE_PPS
#define ERTM_SYNC_SOURCE_RF_TRIGGER	ERTM_COMMON_SYNC_SOURCE_RF_TRIGGER

struct ertm_sync_states {
	int	sync_state;
	char	*label;
	char	*description;
};
extern struct ertm_sync_states ertm_sync_states[];

/* WR enable/disable modes */
#define	ERTM_WR_MASTER		WRC_MODE_MASTER
#define	ERTM_WR_SLAVE		WRC_MODE_SLAVE
#define	ERTM_WR_FREE_RUNNING	WRC_MODE_UNKNOWN	/* disable = 0 */
#define	ERTM_WR_OCXO		ERTM_WR_FREE_RUNNING

/* library operation modes:
 *
 *  ERTM_DEFERRED	operations deferred (cached) until ertm_commit() is called
 *  ERTM_IMMEDIATE	config operations executed synchronously
 *  ERTM_OPTIMIZED	same as ERTM_IMMEDIATE, but UART comm sped up (not implemented)
 *  ERTM_SIMULATED	no interaction with actual hardware
 */
#define	ERTM_DEFERRED	1
#define	ERTM_IMMEDIATE	2
#define	ERTM_OPTIMIZED	3
#define	ERTM_SIMULATED	4

/* firmware metadata according to The Convention (see
 * https://gitlab.com/ohwr/project/fpga-dev-id/blob/master/device-structure.rst
 * probably, only version and source_id are useful here
 */
struct ertm_device_metadata {
	union {
	    char	fpga_build_info[256];
	    struct {
		uint32_t	vendor_id;
		uint32_t	device_id;
		uint32_t	version;
		uint32_t	byte_order_mark;
		unsigned char	source_id[16];
		uint32_t	capability_mask;
		unsigned char	vendor_uuid[16];
		char		fpga_buildinfo_text[200];
	    };
	};
};

struct ertm_board_info {
	/* module serials and MACs */
	char		ertm14_serial[32];
	char		ertm15_serial[32];
	union {
	    uint8_t	ertm14_mac1_bytes[8];
	    uint64_t	ertm14_mac1;
	};
	union {
	    uint8_t	ertm14_mac2_bytes[8];
	    uint64_t	ertm14_mac2;
	};
	/* wrpc-sw version lore */
        char		wrpc_sw_commit_id[32];
        char		wrpc_sw_build_date[16];
        char		wrpc_sw_build_time[16];
        char		wrpc_sw_build_by[32];
	/* MMC firmware versions */
	char		ertm14_firmware_version[32];
	char		ertm15_firmware_version[32];
	uint32_t        calibration_date;

	/* unused */
	struct ertm_device_metadata
			firmware_metadata;
};

/* a bad sensor value */
#define ERTM_MINUS_INFINITY (-1.0e9)

struct ertm_temperatures {	/* celsius SVP */
	double	fpga;			/* eRTM 14 I2C temp  0x49 */
	double	power_supplies14;	/* eRTM 14 I2C temp  0x48 */
	double	dds_lo;			/* eRTM 15 I2C temp1 0x4a */
	double	dds_ref;		/* eRTM 15 I2C temp1 0x4d */
	double	lo_amp;			/* eRTM 15 I2C temp1 0x49 */
	double	ltc6150;		/* eRTM 15 I2C temp1 0x4b */
	double	ocxo_near;		/* eRTM 15 I2C temp1 0x4e */
	double	ocxo_under;		/* eRTM 15 I2C temp1 0x4f */
	double	power_supplies15;	/* eRTM 15 I2C temp1 0x48 */
	double	ref_amp;		/* eRTM 15 I2C temp1 0x4c */
	double	clka;			/* eRTM 15 I2C temp2 0x4c */
	double	clkb;			/* eRTM 15 I2C temp2 0x49 */
	double  unused[4];		/* future extensions */
};

struct ertm_voltages {		/* volts SVP */
	double	p12v_ertm15;
	double	p3v3_ertm15;
	double	pocxo;
	double	p9v0_lo;
	double	p9v0_ref;
	double	ocxo_curr;	/* this is a bizarre place for mA */
	double	p12v_ertm14;
	double	p3v3_ertm14;
	double	unused[16];
};

struct ertm_nco_reset {
	int		enabled;
	union {
		int	subscribed;
		int	sync_source;
	};
	uint32_t	current_stream_id;
	uint32_t	rx_count;
	uint32_t	rx_timeouts;
	uint32_t	reset_count;
	uint32_t	connector;
	uint32_t	unused[7];
};

struct ertm_nco_status {
	union {
	    struct ertm_nco_reset nco_status[2];
	    struct {
		struct ertm_nco_reset lo;
		struct ertm_nco_reset ref;
	    };
	};
};

struct ertm_wr_status
{
	/* FIXME: copied, not #include'd, from wrc_diags_regs.h */
	/* this is an alias of struct WRC_DIAGS_WB */
	uint32_t VER;			/* [0x0]: REG Version register */
	uint32_t CTRL;			/* [0x4]: REG Ctrl */
	uint32_t WDIAG_SSTAT;	/* [0x8]: REG WRPC Diag: servo status */
	uint32_t WDIAG_PSTAT;	/* [0xc]: REG WRPC Diag: Port status */
	uint32_t WDIAG_PTPSTAT; /* [0x10]: REG WRPC Diag: PTP state */
	uint32_t WDIAG_ASTAT;	/* [0x14]: REG WRPC Diag: AUX state */
	uint32_t WDIAG_TXFCNT;	/* [0x18]: REG WRPC Diag: Tx PTP Frame cnts */
	uint32_t WDIAG_RXFCNT;	/* [0x1c]: REG WRPC Diag: Rx PTP Frame cnts */
	uint32_t WDIAG_SEC_MSB; /* [0x20]: REG WRPC Diag:local time [msb of s] */
	uint32_t WDIAG_SEC_LSB; /* [0x24]: REG WRPC Diag: local time [lsb of s] */
	uint32_t WDIAG_NS;		/* [0x28]: REG WRPC Diag: local time [ns] */
	uint32_t WDIAG_MU_MSB;	/* [0x2c]: REG WRPC Diag: Round trip (mu) [msb of ps] */
	uint32_t WDIAG_MU_LSB;	/* [0x30]: REG WRPC Diag: Round trip (mu) [lsb of ps] */
	uint32_t WDIAG_DMS_MSB; /* [0x34]: REG WRPC Diag: Master-slave delay (dms) [msb of ps] */
	uint32_t WDIAG_DMS_LSB; /* [0x38]: REG WRPC Diag: Master-slave delay (dms) [lsb of ps] */
	uint32_t WDIAG_ASYM;	/* [0x3c]: REG WRPC Diag: Total link asymmetry [ps] */
	uint32_t WDIAG_CKO;		/* [0x40]: REG WRPC Diag: Clock offset (cko) [ps] */
	uint32_t WDIAG_SETP;	/* [0x44]: REG WRPC Diag: Phase setpoint (setp) [ps] */
	uint32_t WDIAG_UCNT;	/* [0x48]: REG WRPC Diag: Update counter (ucnt) */
	uint32_t WDIAG_TEMP;	/* [0x4c]: REG WRPC Diag: Board temperature [C degree] */
	uint32_t WDIAG_AUX0_DETAIL_STAT; /* [0x50]: REG (ro) WRPC Diag: Aux0 detailed clock status */
	uint32_t WDIAG_AUX1_DETAIL_STAT; /* [0x54]: REG (ro) WRPC Diag: Aux1 detailed clock status */
	uint32_t WDIAG_AUX2_DETAIL_STAT; /* [0x58]: REG (ro) WRPC Diag: Aux2 detailed clock status */
	uint32_t WDIAG_AUX3_DETAIL_STAT; /* [0x5c]: REG (ro) WRPC Diag: Aux3 detailed clock status */
	uint32_t WDIAG_RX_ERR_CNT; /* [0x60]: REG (ro) WRPC Diag: RX Error count */
	uint32_t WDIAG_SERVO_UPTIME_MSB; /* [0x64]: REG (ro) WRPC Diag: Servo Up Timestamp (MSB) */
	uint32_t WDIAG_SERVO_UPTIME_LSB; /* [0x68]: REG (ro) WRPC Diag: Servo Up Timestamp (LSB) */
	uint32_t WDIAG_SERVO_RESTART_COUNT; /* [0x6c]: REG (ro) WRPC Diag: Servo restart count */
	uint32_t WDIAG_BITSLIDE; /* [0x70]: REG (ro) WRPC Diag: Transceiver bitslide */
	uint32_t WDIAG_DELTA_RX_M; /* [0x74]: REG (ro) WRPC Diag: delta_Rx_M parameter from the link delay model */
	uint32_t WDIAG_DELTA_RX_S; /* [0x78]: REG (ro) WRPC Diag: delta_Rx_S parameter from the link delay model */
	uint32_t WDIAG_DELTA_TX_M; /* [0x7c]: REG (ro) WRPC Diag: delta_Tx_M parameter from the link delay model */
	uint32_t WDIAG_DELTA_TX_S; /* [0x80]: REG (ro) WRPC Diag: delta_Tx_S parameter from the link delay model */
	uint32_t WDIAG_SPLL_HY; /* [0x84]: REG (ro) WRPC Diag: SoftPLL Helper DAC value (HY) */
	uint32_t WDIAG_SPLL_MY; /* [0x88]: REG (ro) WRPC Diag: SoftPLL Main DAC value (MY) */
};

struct ertm_streamer_status
{
/* FIXME: copied, not #include'd, from wr_streamers.h
 * This structure is read only. It does have the same format as the streamer's memory map but
 * you can only use it to read the diagnostic values and nothing else. The xxxCFG and
 * xxxCTRL register are just placeholders, they DO NOTHING */

  /* [0x0]: REG Version register */
  uint32_t VER;
  /* [0x4]: REG Statistics status and ctrl register */
  uint32_t SSCR1;
  /* [0x8]: REG Statistics status and ctrl register */
  uint32_t SSCR2;
  /* [0xc]: REG Statistics status and ctrl register */
  uint32_t SSCR3;
  /* [0x10]: REG Rx statistics */
  uint32_t RX_STAT0;
  /* [0x14]: REG Rx statistics */
  uint32_t RX_STAT1;
  /* [0x18]: REG Tx statistics */
  uint32_t TX_STAT2;
  /* [0x1c]: REG Tx statistics */
  uint32_t TX_STAT3;
  /* [0x20]: REG Rx statistics */
  uint32_t RX_STAT4;
  /* [0x24]: REG Rx statistics */
  uint32_t RX_STAT5;
  /* [0x28]: REG Rx statistics */
  uint32_t RX_STAT6;
  /* [0x2c]: REG Rx statistics */
  uint32_t RX_STAT7;
  /* [0x30]: REG Rx statistics */
  uint32_t RX_STAT8;
  /* [0x34]: REG Rx statistics */
  uint32_t RX_STAT9;
  /* [0x38]: REG Rx statistics */
  uint32_t RX_STAT10;
  /* [0x3c]: REG Rx statistics */
  uint32_t RX_STAT11;
  /* [0x40]: REG Rx statistics */
  uint32_t RX_STAT12;
  /* [0x44]: REG Rx statistics */
  uint32_t RX_STAT13;
  /* [0x48]: REG Tx Config Reg 0 */
  uint32_t TX_CFG0;
  /* [0x4c]: REG Tx Config Reg 1 */
  uint32_t TX_CFG1;
  /* [0x50]: REG Tx Config Reg 2 */
  uint32_t TX_CFG2;
  /* [0x54]: REG Tx Config Reg 3 */
  uint32_t TX_CFG3;
  /* [0x58]: REG Tx Config Reg 4 */
  uint32_t TX_CFG4;
  /* [0x5c]: REG Tx Config Reg 4 */
  uint32_t TX_CFG5;
  /* [0x60]: REG Rx Config Reg 0 */
  uint32_t RX_CFG0;
  /* [0x64]: REG Rx Config Reg 1 */
  uint32_t RX_CFG1;
  /* [0x68]: REG Rx Config Reg 2 */
  uint32_t RX_CFG2;
  /* [0x6c]: REG Rx Config Reg 3 */
  uint32_t RX_CFG3;
  /* [0x70]: REG Rx Config Reg 4 */
  uint32_t RX_CFG4;
  /* [0x74]: REG Rx Config Reg 5 */
  uint32_t RX_CFG5;
  /* [0x78]: REG TxRx Config Override */
  uint32_t CFG;
  /* [0x7c]: REG DBG Control register */
  uint32_t DBG_CTRL;
  /* [0x80]: REG DBG Data */
  uint32_t DBG_DATA;
  /* [0x84]: REG Test value */
  uint32_t DUMMY;
  /* [0x88]: REG Reset Register */
  uint32_t RSTR;
  /* [0x8c]: REG Rx statistics */
  uint32_t RX_STAT15;
  /* [0x90]: REG Rx statistics */
  uint32_t RX_STAT16;
  /* [0x94]: REG Rx statistics */
  uint32_t RX_STAT17;
  /* [0x98]: REG Rx statistics */
  uint32_t RX_STAT18;
  /* [0x9c]: REG Rx statistics */
  uint32_t RX_STAT19;
  /* [0xa0]: REG Rx statistics */
  uint32_t RX_STAT20;
  /* [0xa4]: REG Rx Config Reg 6 */
  uint32_t RX_CFG6;
};

/* as a general rule, all methods in libertm return an integer exit
 * code 0 in case of success and < 0 in case of error, the type of error
 * mapped to an errno value
 */

/* FIXME: address shall define uniquely a ttyUSB -> UART, an IP address
 * in the WR network or further unique address of eRTM/host
 * The handle is an opaque pointer to keep status of the connection
 */
struct ertm_status;
struct ertm_status *ertm_init(const char *address);
void ertm_exit(struct ertm_status *handle);		/* end connection, destroy handle */
struct ertm_lib_version *ertm_lib_version(void);

int ertm_get_board_info(struct ertm_status *handle,
			struct ertm_board_info *info);

/* all methods below have an implicit first arg struct ertm_status *
 * argument, omitted for brevity's sake
 */

#define ERTM_LO_DEFAULT_FREQ	0x3341BFBD	/* 200.222 MHz */
#define ERTM_REF_DEFAULT_FREQ	0x39374BC6	/* 223.499999 MHz */
#define	ERTM_CLKAB_DEFAULT_FREQ	ERTM_CLKAB_125MHz	/* ditto */

/* connector can be any of ERTM_{CLKA,CLKB,REF,LO}. For REF and LO, the
 * channel parameter is ignored; for CLKA/CLKB, the freq parameter is
 * one of the ertm_clkab_freq values, while for REF/LO, it is an actual
 * uint32_t where 2**32 = 1GHz
 */
int ertm_get_freq(struct ertm_status *handle,
		enum ertm_connector connector, int channel, uint32_t *freq);
int ertm_set_freq(struct ertm_status *handle,
		enum ertm_connector connector, int channel, uint32_t freq);

/* the following refer only to REF/LO connectors */
int ertm_channel_enable(struct ertm_status *handle,
		enum ertm_connector connector, int channel, int enable);		/* default disabled */
int ertm_get_enable_state(struct ertm_status *handle,
		enum ertm_connector connector, int channel, uint8_t *enable_state);	/* usually on/off, thence boolean */
int ertm_get_power(struct ertm_status *handle,
		enum ertm_connector connector, double *power);				/* power level in dBm */
int ertm_get_channel_power(struct ertm_status *handle,
		enum ertm_connector connector, int channel, double *power);		/* power per channel in dBm */
int ertm_get_channel_power_all(struct ertm_status *handle,
		enum ertm_connector connector, uint32_t valid_mask, double *power);	/* powers in dBm */
int ertm_force_measure_channels_power( struct ertm_status *handle );
int ertm_dds_set_level_adjust(struct ertm_status *handle,
		enum ertm_connector connector, double level);			/* level in [0,1] */
int ertm_dds_get_level_adjust(struct ertm_status *handle,
		enum ertm_connector connector, double *level);			/* level in [0,1] */
int ertm_get_sync_state(struct ertm_status *handle,
		enum ertm_connector connector, int channel, int *sync_state);

/* monitoring */
int ertm_get_ocxo_current(struct ertm_status *handle, double *current);			/* amperes */
int ertm_get_temperatures(struct ertm_status *handle, struct ertm_temperatures *temps);	/* all celsius */
int ertm_get_voltages(struct ertm_status *handle, struct ertm_voltages *volts);		/* all volt */

/* system-wide NCO reset */
int ertm_rf_nco_reset_enable(struct ertm_status *handle, int enable);
int ertm_rf_nco_reset(struct ertm_status *handle);
int ertm_nco_reset_subscribe(struct ertm_status *handle,
		enum ertm_connector, int mode, int channel, uint32_t stream_id);
int ertm_nco_reset_get_status(struct ertm_status *handle, struct ertm_nco_reset status[]);

/* WR enable/diagnostics */
struct ertm_wr_status;						/* to be defined with rabbits */
int ertm_wr_enable(struct ertm_status *handle, int enable);	/* free-running OCXO if disabled */
int ertm_wr_status(struct ertm_status *handle, int *link_up, int *is_locked);
int ertm_wr_diags(struct ertm_status *handle, struct ertm_wr_status *status);

/* streamer latency and timeout settings */
int ertm_reset_streamer_diags(struct ertm_status *handle);
int ertm_streamer_diags(struct ertm_status *handle, struct ertm_streamer_status *status);

int ertm_set_streamers_latency(struct ertm_status *handle, uint32_t cycles16n);
int ertm_set_streamers_timeout(struct ertm_status *handle, uint32_t cycles16n);
int ertm_get_streamers_latency_timeout(struct ertm_status *handle,
	    uint32_t *latency_cycles16n, uint32_t *timeout_cycles16n);
					/* all in 16ns-cycle units */

int ertm_configure_spll_debug_dump(struct ertm_status *handle, int enabled, int undersample);
int ertm_read_spll_debug_data( struct ertm_status *handle, uint32_t *buf, size_t *buf_size );
int ertm_execute_shell_command(struct ertm_status *handle, char *cmd);

#ifdef __cplusplus
}
#endif

#endif /* _LIBERTM_H_ */
