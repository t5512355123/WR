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

#ifndef __AD9910_H
#define __AD9910_H


#include <stdint.h>
#include <stdio.h>


#include "dev/gpio.h"
#include "dev/bb_spi.h"

struct ad9910_device {
    struct spi_bus *bus;
    void (*trigger_io_update)(struct ad9910_device *dev);
};

struct ad9910_config_reg {
    int addr;
    uint64_t value;
    int nbits;
};

int ad9910_program( struct ad9910_device *dev, uint64_t freq_hz, int phase, int fs_current );
uint64_t ad9910_read(struct ad9910_device *dev, uint32_t reg, int nbits);
void ad9910_write(struct ad9910_device *dev, uint32_t reg, uint64_t value, int nbits);
int ad9910_probe( struct ad9910_device *dev, struct spi_bus *bus, void (*trigger_io_update)(struct ad9910_device *dev) );
void ad9910_trigger_update(struct ad9910_device *dev);
void ad9910_configure_sync( struct ad9910_device *dev, int enable, int fine_delay_taps );
uint64_t ad9910_ftw_to_frequency( uint64_t ftw );
uint64_t ad9910_frequency_to_ftw( uint64_t freq_hz );

#endif
