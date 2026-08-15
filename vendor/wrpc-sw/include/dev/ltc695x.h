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

#ifndef __LTC695X_H
#define __LTC695X_H

#include <stdint.h>
#include <stdio.h>

#include "dev/gpio.h"
#include "dev/bb_spi.h"


#define LTC6953_PD_NORMAL (0)
#define LTC6953_PD_MUTE   (1)
#define LTC6953_PD_OUTPUT (2)
#define LTC6953_PD_OUTPUT_AND_DIVIDER (3)

#define LTC6953_OR0_MP_DIV_MASK (0xf8)
#define LTC6953_OR0_MP_DIV_SHIFT (3)

#define LTC6953_OR0_MD_DIV_MASK (0x7)
#define LTC6953_OR0_MD_DIV_SHIFT (0)

#define LTC6953_OR1_SRQEN (1<<7)
#define LTC6953_OR1_OINV (1<<4)

#define LTC6953_OR1_MODE_MASK (0x60)
#define LTC6953_OR1_MODE_SHIFT (5)

#define LTC695x_R0_LOCK (1<<2)


struct ltc695x_device {
    struct spi_bus *bus;
};

struct ltc695x_config_reg {
    uint16_t addr;
    uint8_t value;
};

struct ltc695x_config {
    int n_regs;
    struct ltc695x_config_reg regs[];
};


int ltc695x_init( struct ltc695x_device *dev, struct spi_bus *bus );
uint8_t ltc695x_read(struct ltc695x_device *dev, uint32_t reg);
void ltc695x_write(struct ltc695x_device *dev, uint32_t reg, uint8_t value);
int ltc695x_configure(struct ltc695x_device *dev, struct ltc695x_config* cfg);

int ltc6953_enable_output( struct ltc695x_device *dev, int output, int enabled );
int ltc6953_configure_output( struct ltc695x_device *dev, int output, int divider, int invert );
int ltc6953_set_srqen( struct ltc695x_device *dev, int output, int en );
int ltc6950_set_syncen( struct ltc695x_device *dev, uint32_t out_mask );

#endif
