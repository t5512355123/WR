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

#ifndef __AD9520_H
#define __AD9520_H

#include "board.h"
#include "dev/i2c.h"
#include "dev/ad951x.h"

#define AD9510_BIT_DELAY 100


struct ad9520_device {
    struct i2c_bus *bus;
    uint8_t addr;
};

void ad9520_write(struct ad9520_device *dev, uint32_t reg, uint8_t value);
uint8_t ad9520_read(struct ad9520_device *dev, uint32_t reg);
void ad9520_soft_reset(struct ad9520_device *dev);
int ad9520_init(struct ad9520_device *dev, struct i2c_bus *bus, uint8_t addr);
int ad9520_configure(struct ad9520_device *dev, struct ad95xx_config *cfg);
int ad9520_enable_output(struct ad9520_device *dev, int channel, int enabled );
int ad9520_set_output_divider( struct ad9520_device *dev, int channel, int divider);

#endif
