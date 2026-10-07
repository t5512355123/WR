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

#include <stdint.h>

#include "board.h"
#include "pp-printf.h"
#include "dev/gpio.h"
#include "dev/bb_spi.h"

void bb_spi_delay(struct spi_bus *bus)
{
    int i;
    for(i=0;i<bus->bit_delay;i++)
      asm volatile("nop");
}

void bb_spi_cs(struct spi_bus *bus, int cs)
{
    if(bus->pin_cs)
    {
        bb_spi_delay(bus);
        gen_gpio_out(bus->pin_cs, !cs);
    }
}

uint64_t bb_spi_read(struct spi_bus *bus, int n_bits)
{
    uint64_t rv = 0;
    int i;
    bb_spi_delay(bus);
    gen_gpio_out(bus->pin_sck, 0);
    bb_spi_delay(bus);
    gen_gpio_out(bus->pin_mosi, 0);
    gen_gpio_set_dir(bus->pin_miso, 0);
    bb_spi_delay(bus);

    for(i=0;i<n_bits;i++)
    {
        rv<<=1;

        if( bus->rd_falling_edge )
        {
            if(gen_gpio_in(bus->pin_miso))
               rv |= 1ULL;
        }

    	gen_gpio_out(bus->pin_sck, 1);
    	bb_spi_delay(bus);

        if( !bus->rd_falling_edge )
        {
            if(gen_gpio_in(bus->pin_miso))
               rv |= 1ULL;
        }


    	gen_gpio_out(bus->pin_sck, 0);
	    bb_spi_delay(bus);
    }

    bb_spi_delay(bus);

    return rv;
}

void bb_spi_write(struct spi_bus *bus, uint64_t d, int n_bits)
{
    int i;
    bb_spi_delay(bus);

    gen_gpio_out(bus->pin_mosi, 0);
    gen_gpio_set_dir(bus->pin_mosi, 1);
    gen_gpio_out(bus->pin_sck, 0);
    bb_spi_delay(bus);

    for(i=0;i<n_bits;i++)
    {
        
    	gen_gpio_out(bus->pin_mosi, d & (1ULL<<(n_bits-1-i)) ? 1 : 0);
    	bb_spi_delay(bus);
    	gen_gpio_out(bus->pin_sck, 1);
    	bb_spi_delay(bus);
    	gen_gpio_out(bus->pin_sck, 0);
    	bb_spi_delay(bus);
    }

}


void bb_spi_xfer(struct spi_bus *bus, uint64_t din, uint64_t *d_out, int n_bits)
{
    int i;
    uint64_t rv = 0;
    bb_spi_delay(bus);

    gen_gpio_out(bus->pin_mosi, 0);
    gen_gpio_set_dir(bus->pin_mosi, 1);
    gen_gpio_out(bus->pin_sck, 0);
    bb_spi_delay(bus);

    for(i=0;i<n_bits;i++)
    {
        rv<<=1;

        if( bus->rd_falling_edge )
        {
            if(gen_gpio_in(bus->pin_miso))
               rv |= 1ULL;
        }

        gen_gpio_out(bus->pin_mosi, din & (1ULL<<(n_bits-1-i)) ? 1 : 0);
    	bb_spi_delay(bus);
    	gen_gpio_out(bus->pin_sck, 1);
    	bb_spi_delay(bus);

        if( !bus->rd_falling_edge )
        {
            if(gen_gpio_in(bus->pin_miso))
               rv |= 1ULL;
        }

    	gen_gpio_out(bus->pin_sck, 0);
    	bb_spi_delay(bus);
    }

    if(d_out)
        *d_out = rv;

}

/*
 * Declare GPIOs for bitbanging SPI
 * set initial state of outputs
 * set SPI speed by configuring bit delay
 */

void bb_spi_create( struct spi_bus *bus, 
                    const struct gpio_pin *pin_cs,
                    const struct gpio_pin *pin_mosi,
                    const struct gpio_pin *pin_miso,
                    const struct gpio_pin *pin_sck,
                    int bit_delay
                    )
{
    bus->bit_delay = bit_delay;
    bus->pin_cs = pin_cs;
    bus->pin_miso = pin_miso;
    bus->pin_mosi = pin_mosi;
    bus->pin_sck = pin_sck;

    gen_gpio_out( bus->pin_sck, 0 );
    gen_gpio_out( bus->pin_cs, 1 );
    gen_gpio_set_dir( bus->pin_cs, 1 );
    gen_gpio_set_dir( bus->pin_mosi, 1 );
    gen_gpio_set_dir( bus->pin_miso, 0 );
    gen_gpio_set_dir( bus->pin_sck, 1 );
}

void bb_spi_test(struct spi_bus *bus)
{
    pp_printf("Testing SPI bus: CS = 1 pulse, SCK = 2 pulses, MOSI = 3 pulses\n");
    for(;;)
    {
        gen_gpio_out( bus->pin_cs, 1 );
        gen_gpio_out( bus->pin_cs, 0 );

        gen_gpio_out( bus->pin_sck, 1 );
        gen_gpio_out( bus->pin_sck, 0 );
        gen_gpio_out( bus->pin_sck, 1 );
        gen_gpio_out( bus->pin_sck, 0 );

        gen_gpio_out( bus->pin_mosi, 1 );
        gen_gpio_out( bus->pin_mosi, 0 );
        gen_gpio_out( bus->pin_mosi, 1 );
        gen_gpio_out( bus->pin_mosi, 0 );
        gen_gpio_out( bus->pin_mosi, 1 );
        gen_gpio_out( bus->pin_mosi, 0 );
    }
}
