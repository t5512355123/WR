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

#ifndef __FINE_PULSE_GENERATOR_H
#define __FINE_PULSE_GENERATOR_H

#include <stdint.h>

#define FINE_PULSE_GEN_MAX_CHANNELS 6


#define FINE_PULSE_GEN_ENABLED 0x1
#define FINE_PULSE_GEN_NEGATIVE 0x2
#define FINE_PULSE_GEN_USE_EXT_FINE_DELAY 0x4
#define FINE_PULSE_GEN_CONTINUOUS 0x8
#define FINE_PULSE_GEN_USE_EXT_TRIGGER 0x10
#define FINE_PULSE_GEN_CH_ARMED 0x20

#define FINE_PULSE_GEN_TARGET_KINTEXU (1<<0)
#define FINE_PULSE_GEN_TARGET_KINTEX7 (1<<1)

struct fine_pulse_gen_channel 
{
    uint32_t flags;
    int pps_offset_ps;
    int index;
    int pulse_length_ps;
    int delay_tap_size_ps;
    int (*set_external_delay)( struct fine_pulse_gen_channel* ch, int n_taps );
};

struct fine_pulse_gen_device {
    void* base;
    int calibrate_fine_delay;
    int serdes_bit_length_ps;
    int serdes_ratio;
    struct fine_pulse_gen_channel channels[FINE_PULSE_GEN_MAX_CHANNELS];
};

int fine_pulse_gen_init( struct fine_pulse_gen_device *dev, void* base, uint32_t target );
void fine_pulse_gen_setup_channel ( struct fine_pulse_gen_device* dev, int ch, int enable, int pps_offset_ps,  int length_ps, int flags );
void fine_pulse_gen_set_external_fine_delay ( struct fine_pulse_gen_device* dev, int ch, int tap_size,  int (*set_external_delay)( struct fine_pulse_gen_channel* ch, int ) );
void fine_pulse_gen_trigger( struct fine_pulse_gen_device* dev, uint32_t mask, int force_now );
int fine_pulse_gen_is_armed( struct fine_pulse_gen_device* dev, int ch );
void fine_pulse_gen_force_pulse( struct fine_pulse_gen_device* dev, int ch );
int fine_pulse_gen_is_triggered( struct fine_pulse_gen_device* dev, uint32_t mask );
void fine_pulse_gen_reset( struct fine_pulse_gen_device *dev );

#endif
