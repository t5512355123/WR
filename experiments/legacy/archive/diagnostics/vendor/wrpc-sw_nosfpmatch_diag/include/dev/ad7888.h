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

#ifndef __AD7888_H
#define __AD7888_H

#include <stdint.h>
#include "util.h"

struct spi_bus;

struct ad7888_device {
    uint16_t channel[8];
    uint16_t channel_valid;
    uint16_t channel_mask;
    int8_t current_ch;
    struct spi_bus* bus;
    timeout_t poll_tmo;
    uint8_t conversion_pending;
};

int ad7888_create( struct ad7888_device *dev, struct spi_bus *bus );
void ad7888_start_conversion( struct ad7888_device *dev, uint16_t channel_mask );
int ad7888_poll( struct ad7888_device *dev );
int ad7888_meas_channel( struct ad7888_device *dev, int ch );

#endif
