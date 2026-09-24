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

#ifndef __M24025AA_H
#define __M24025AA_H

#include <stdint.h>

#include "dev/bb_i2c.h"

struct m24aa025_device 
{
    struct i2c_bus *bus;
    uint8_t addr;
};

int m24aa025_init(struct m24aa025_device *dev, struct i2c_bus *i2c, uint8_t addr);
int m24aa025_read_mac(struct m24aa025_device *dev, uint8_t *mac);

#endif
