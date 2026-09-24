/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __ERTM15_RF_DISTR_H
#define __ERTM15_RF_DISTR_H

#include <stdint.h>
#include "ertm-common.h"
#include "util.h"

#define ERTM15_RF_OUT_ON	ERTM_COMMON_RF_OUT_ON
#define ERTM15_RF_OUT_MONITOR	ERTM_COMMON_RF_OUT_MONITOR
#define ERTM15_RF_OUT_OFF	ERTM_COMMON_RF_OUT_OFF

#define ERTM15_RF_LO 0
#define ERTM15_RF_REF 1

struct ad7888_device;

#define PWR_MEAS_STATE_IDLE 0
#define PWR_MEAS_STATE_PICK_CHANNEL 1
#define PWR_MEAS_STATE_READ_ADC 2
#define PWR_MEAS_STATE_DONE 3
#define PWR_MEAS_STATE_START 4
#define PWR_MEAS_STATE_START_ADC 5
#define PWR_MEAS_STATE_FINISH 6

#define PWR_MEAS_STABILIZE_TMO_MS 5

struct ertm15_rf_distribution_device {
    uint16_t pwr_lo_valid;
    uint16_t lo_enabled;
    uint16_t pwr_ref_valid;
    uint16_t ref_enabled;
    int pwr_lo_ch [ 16 ];
    int pwr_ref_ch [ 16 ];
    int pwr_lo_in;
    int pwr_ref_in;
    struct ad7888_device *pwr_mon_adc;
    int pwr_meas_state;
    int pwr_meas_channel;
    int pwr_meas_force;
    uint32_t pwr_meas_lo_valid_next;
    uint32_t pwr_meas_ref_valid_next;
    timeout_t pwr_meas_tmo;
    uint32_t pwr_meas_start_tics;
};


void ertm15_rf_distr_init( struct ertm15_rf_distribution_device *dev, struct ad7888_device *pwr_mon_adc );
int ertm15_rf_distr_measure_power ( struct ertm15_rf_distribution_device *dev );
int ertm15_rf_distr_pwrmon_update(  struct ertm15_rf_distribution_device *dev );
int ertm15_rf_distr_measure_power_restart( struct ertm15_rf_distribution_device *dev, int force );
int ertm15_rf_distr_is_pwrmon_idle( struct ertm15_rf_distribution_device *dev );
void ertm15_rf_distr_output_enable( struct ertm15_rf_distribution_device *dev, int path, int channel, int enabled );
void ertm15_update_rf_switches( struct ertm15_rf_distribution_device *dev );


#endif
