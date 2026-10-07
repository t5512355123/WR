/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Copyright 2020-2021 CERN
 * Author: Juan David Gonzalez Cobas
 *
 * This module exports magic constants for the cli
 */

#include <limits.h>
#include "wrpc.h"
#include "libertm.h"
#include "board-state.h"

struct ertm_cli_magic_numbers {

    /* libertm.h */
	int path_max;
	int ertm_clka;
	int ertm_clkb ;
	int ertm_lo;
	int ertm_ref;

    /* BOARD-STATE.H */
	int ertm14_sync_source_none;
	int ertm14_sync_source_pps;
	int ertm14_sync_source_rf_trigger;
	int ertm14_max_uart_link_payload;

    /* LIBERTM.H */
	int ertm_wr_master;
	int ertm_wr_slave;
	int ertm_wr_free_running;

    /* sizeof(struct ertm_voltages)/sizeof(double); */
	int Sensor_Array;
    /* sizeof(struct ertm_board_info)/sizeof(unsigned int) */
	int BoardInfo;
};

struct ertm_cli_magic_numbers ertm_magics = {
	.path_max = PATH_MAX,
	.ertm_clka = ERTM_CLKA,
	.ertm_clkb  = ERTM_CLKB,
	.ertm_lo = ERTM_LO,
	.ertm_ref = ERTM_REF,

	.ertm14_sync_source_none = ERTM14_SYNC_SOURCE_NONE,
	.ertm14_sync_source_pps = ERTM14_SYNC_SOURCE_PPS,
	.ertm14_sync_source_rf_trigger = ERTM14_SYNC_SOURCE_RF_TRIGGER,
	.ertm14_max_uart_link_payload = ERTM14_MAX_UART_LINK_PAYLOAD,

	.ertm_wr_master = ERTM_WR_MASTER,
	.ertm_wr_slave = ERTM_WR_SLAVE,
	.ertm_wr_free_running = ERTM_WR_FREE_RUNNING,

	.Sensor_Array = sizeof(struct ertm_voltages)/sizeof(double),
	.BoardInfo = sizeof(struct ertm_board_info)/sizeof(unsigned int),
};
