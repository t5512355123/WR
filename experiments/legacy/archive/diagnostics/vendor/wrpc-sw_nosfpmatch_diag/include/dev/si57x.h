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

#ifndef __SI57x_h
#define __SI57x_h

#include <stdint.h>
#include <stdio.h>

#include "dev/gpio.h"
#include "dev/bb_i2c.h"

struct wr_si57x_interface_device
{
	void *base_addr;
	uint8_t i2c_addr;
	struct gpio_pin pin_scl;
	struct gpio_pin pin_sda;
	struct gpio_device gpio_i2c;
	struct i2c_bus master;
	int n1, hsdiv;
	uint64_t rfreq;
};

void si57x_gpio_out(const struct gpio_pin *pin, int value);
void si57x_gpio_set_dir(const struct gpio_pin *pin, int dir);
int si57x_gpio_in(const struct gpio_pin *pin);
void si57x_read( struct wr_si57x_interface_device *dev, uint8_t addr, uint8_t *data, int count );
void si57x_write( struct wr_si57x_interface_device *dev, uint8_t addr, uint8_t *data, int count );
void si57x_get_xtal_frequency( struct wr_si57x_interface_device *dev, uint32_t* freq_hz );
int si57x_calc_frequency( uint32_t f_xtal, uint32_t freq_hz, uint64_t *rfreq_out, int* hsdiv_out, int* n1_out );
void si57x_reset(struct wr_si57x_interface_device *dev );
int si57x_set_frequency( struct wr_si57x_interface_device *dev, uint32_t f_xtal, uint32_t freq_hz, int vco_gain );

void wr_si57x_interface_init( struct wr_si57x_interface_device *dev, uint32_t base_addr, uint8_t i2c_addr );

#endif

