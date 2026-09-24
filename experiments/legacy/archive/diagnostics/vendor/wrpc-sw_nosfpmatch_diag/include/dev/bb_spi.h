/*
 * DSI Shield
 *
 * Copyright (C) 2013-2015 twl <twlostow@printf.cc>
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

#ifndef __BB_SPI_H
#define __BB_SPI_H

#include "dev/gpio.h"

struct spi_bus
{
  const   struct   gpio_pin *pin_cs;
  const   struct   gpio_pin *pin_mosi;
  const struct   gpio_pin *pin_miso;
  const   struct gpio_pin *pin_sck;
  int bit_delay;
  int rd_falling_edge;
};

void bb_spi_create( struct spi_bus *bus, 
                    const struct gpio_pin *pin_cs,
                    const struct gpio_pin *pin_mosi,
                    const struct gpio_pin *pin_miso,
                    const struct gpio_pin *pin_sck,
                    int bit_delay
                    );


void bb_spi_delay(struct spi_bus *bus);
void bb_spi_cs(struct spi_bus *bus, int cs);
uint64_t bb_spi_read(struct spi_bus *bus, int n_bits);
void bb_spi_write(struct spi_bus *bus, uint64_t d, int n_bits);
void bb_spi_xfer(struct spi_bus *bus, uint64_t din, uint64_t *d_out, int n_bits);

#endif
