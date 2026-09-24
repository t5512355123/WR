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


#include "pp-printf.h"
#include "dev/ad951x.h"

// Write to ad951x via SPI
void ad951x_write(struct ad951x_device *dev, uint32_t reg, uint32_t value) {
    bb_spi_cs(dev->bus, 1);
    bb_spi_write(dev->bus, reg & 0x1fff, 16);
    bb_spi_write(dev->bus, value & 0xff, 8);
    bb_spi_cs(dev->bus, 0);
}

// Read from ad951x via SPI
uint32_t ad951x_read(struct ad951x_device *dev, uint32_t reg) {
    uint32_t rv;
    bb_spi_cs(dev->bus, 1);
    bb_spi_write( dev->bus, 0x8000 | (reg & 0x1fff), 16);  // read address cmd
    rv = bb_spi_read(dev->bus, 8);
    bb_spi_cs(dev->bus, 0);
    return rv;
}

// Configure ad951x
int ad951x_configure(struct ad951x_device *dev, struct ad95xx_config *cfg) {
    int i;
    for(i = 0; i < cfg->n_regs; i++) {
        ad951x_write(dev, cfg->regs[i].addr, cfg->regs[i].value);
    }

    ad951x_write(dev, 0x232, 0x01);  // commit

    for(i = 0; i < cfg->n_regs; i++) {
        ad951x_read(dev, cfg->regs[i].addr);
    }

    int lock_timeout = 1000;

    while(lock_timeout--)
    {
        uint8_t r = ad951x_read(dev, 0x01F);
        if( r & 0x1 )
            return 0;
    }

    pp_printf("ad9516: can't lock.\n");

    return -1;
}

int ad951x_init(struct ad951x_device *dev, struct spi_bus *spi, struct gpio_pin *pin_reset, struct gpio_pin *pin_lock)
{
    dev->bus = spi;
    dev->pin_reset = pin_reset;
    dev->pin_lock = pin_lock;

    if( dev->pin_reset )
    {
        gen_gpio_set_dir(dev->pin_reset, 1);
        gen_gpio_out(dev->pin_reset, 0);
        //timer_delay(1);
        gen_gpio_out(dev->pin_reset, 1);
        //timer_delay(1);
    }

    ad951x_write(dev, 0x00, 0x99);  // bidir mode, long command
    ad951x_write(dev, 0x232, 0x01);  // commit

    uint8_t id = ad951x_read( dev, 0x3 );

    return id == 0xc3 ? 0 : -1;
}


#if 0
void ad951x_init() {
    int i;

    // Configure SPI bus to ad951x
    gpio_set_dir(&gpio_pin_div_function, 1);
    gpio_out(&gpio_pin_div_function, 0);
    spi_delay(&bus_ad951x[0]);
    gpio_out(&gpio_pin_div_function, 1);
    spi_delay(&bus_ad951x[0]);

    
    // Configure ad951x
    ad951x_configure(&bus_ad951x[0], &default_config);
    ad951x_configure(&bus_ad951x[1], &default_config);
}
#endif
