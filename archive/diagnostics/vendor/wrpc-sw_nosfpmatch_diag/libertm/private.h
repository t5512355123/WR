/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Copyright 2020-2021 CERN
 * Author: Juan David Gonzalez Cobas
 */

#include <limits.h>
#include <stdint.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <semaphore.h>
#include "libertm.h"
#include "board-state.h"
#include "common-uart-link.h"

#include "hw/wrc_diags_regs.h"
#include "hw/wr_streamers.h"

struct ertm_state {
	struct ertm_board_info		board_info;
	struct ertm14_board_state	board_state;
	struct ertm14_board_state	next_state;
	struct ertm14_board_state	commit_mask;
	struct ertm_temperatures	temperatures;
	struct ertm_voltages		voltages;
	struct ertm_nco_reset		nco_reset;
	union {
		struct ertm_wr_status	wr_status;
		struct wrc_diags	diags_wb;
	};
	int				ptp_enabled;

	/* one of ERTM_DEFERRED, ERTM_IMMEDIATE, ERTM_OPTIMIZED */
	int				mode;
	uint32_t			reserved[64];
};

struct ertm_connection {
	char	*address;
	char	serial_connection[PATH_MAX];
};

struct ertm_status {
	struct ertm_connection connection;
	struct ertm_state *state;
	struct uart_link link;
	struct ertm_mutex_ops *mutex;
	int lock;
	sem_t *semaphore;
	uint32_t reserved[63];
};

static int ertm_voltage_ids[] = {
        ERTM15_VOLTAGE_P12V,
        ERTM15_VOLTAGE_P3V3,
        ERTM15_VOLTAGE_POCXO,
        ERTM15_VOLTAGE_P9V0_LO,
        ERTM15_VOLTAGE_P9V0_REF,
        ERTM15_CURRENT_OCXO,
        ERTM14_VOLTAGE_P12V,
        ERTM14_VOLTAGE_P3V3,
};
static const int ertm_nvoltages =
	sizeof(ertm_voltage_ids)/sizeof(ertm_voltage_ids[0]);

static int ertm_temperature_ids[] = {
        ERTM14_TEMP_FPGA,
        ERTM14_TEMP_DCDC,
        ERTM15_TEMP_LO_DDS,
        ERTM15_TEMP_REF_DDS,
        ERTM15_TEMP_LO_RF,
        ERTM15_TEMP_LTC6150,
        ERTM15_TEMP_OCXO1,
        ERTM15_TEMP_OCXO2,
        ERTM15_TEMP_PSU,
        ERTM15_TEMP_REF_RF,
        ERTM15_TEMP_CLKA_FANOUT,
        ERTM15_TEMP_CLKB_FANOUT,
};
static const int ertm_ntemperatures =
	sizeof(ertm_temperature_ids)/sizeof(ertm_temperature_ids[0]);

extern int ertm_get_board_config(struct ertm_status *st, struct ertm14_board_state *bs);
extern char *ertm_find_usb_port(void);
extern char *ertm_usb_by_function(char *func);

/* big global lock */
extern int ertm_open_lock_file(struct ertm_status *st);
extern int ertm_mutex_acquire(struct ertm_status *st);
extern int ertm_mutex_release(struct ertm_status *st);

extern int ertm_create_semaphore(struct ertm_status *st);
extern int ertm_semaphore_acquire(struct ertm_status *st);
extern int ertm_semaphore_release(struct ertm_status *st);

struct ertm_mutex_ops {
	int (*create)(struct ertm_status *st);
	int (*acquire)(struct ertm_status *st);
	int (*release)(struct ertm_status *st);
};

extern struct ertm_mutex_ops *ertm_flock_mutex;
extern struct ertm_mutex_ops *ertm_semaphore_mutex;
