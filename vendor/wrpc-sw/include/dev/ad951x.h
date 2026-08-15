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


#ifndef __AD951x_H
#define __AD951x_H

#include <stdint.h>

#include "dev/gpio.h"
#include "dev/bb_spi.h"

#define AD951X_BIT_DELAY 100

struct ad95xx_config_reg {
    uint16_t addr;
    uint8_t value;
};

struct ad95xx_config {
    int n_regs;
    struct ad95xx_config_reg regs[];
};

struct ad951x_device {
    struct spi_bus *bus;
    struct gpio_pin *pin_reset;
    struct gpio_pin *pin_lock;
};


void ad951x_write(struct ad951x_device *dev, uint32_t reg, uint32_t value);
uint32_t ad951x_read(struct ad951x_device *dev, uint32_t reg);
int ad951x_configure(struct ad951x_device *dev, struct ad95xx_config *cfg);
int ad951x_init(struct ad951x_device *dev, struct spi_bus *spi, struct gpio_pin *pin_reset, struct gpio_pin *pin_lock);

#endif
