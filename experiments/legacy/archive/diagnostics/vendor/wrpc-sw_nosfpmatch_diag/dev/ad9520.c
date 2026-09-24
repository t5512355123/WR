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

#include "wrc-debug.h"
#include "dev/ad9520.h"
#include "dev/bb_i2c.h"


// Write to AD9510 via I2C
void ad9520_write(struct ad9520_device *dev, uint32_t reg, uint8_t value)
{
//    pp_printf("ad9520_write reg %x value %x\n", reg, value);
    bb_i2c_start( dev->bus );
    bb_i2c_put_byte( dev->bus, dev->addr << 1 );
    bb_i2c_put_byte( dev->bus, reg >> 8);
    bb_i2c_put_byte( dev->bus, reg & 0xff);
    bb_i2c_put_byte( dev->bus, value );
    bb_i2c_stop( dev->bus );
}

// Read from AD9510 via I2C
uint8_t ad9520_read(struct ad9520_device *dev, uint32_t reg) {
    uint8_t rv;
    bb_i2c_start( dev->bus );
    bb_i2c_put_byte( dev->bus, dev->addr << 1 );
    bb_i2c_put_byte( dev->bus, reg >> 8);
    bb_i2c_put_byte( dev->bus, reg & 0xff);
    bb_i2c_repeat_start( dev->bus );
    bb_i2c_put_byte( dev->bus, (dev->addr << 1) | 1 );
    bb_i2c_get_byte( dev->bus, &rv, 1);
    bb_i2c_stop( dev->bus );
    return rv;
}


int ad9520_init(struct ad9520_device *dev, struct i2c_bus *bus, uint8_t addr)
{
    dev->bus = bus;
    dev->addr = addr;

    ad9520_write( dev, 0x00, (1<<5) | (1<<2) );  // soft reset
    ad9520_write( dev, 0x232, 0x01);  // commit

    int id = ad9520_read( dev, 0x3 );
    dev_dbg("Init AD9520: ID = %x (expected: 0x61)\n", id);
    return (id == 0x61 ? 0 : -1);
}

int ad9520_configure(struct ad9520_device *dev, struct ad95xx_config *cfg) 
{
    int i;
    for(i = 0; i < cfg->n_regs; i++) {
        ad9520_write(dev, cfg->regs[i].addr, cfg->regs[i].value);
    }

    ad9520_write(dev, 0x232, 0x01);  // commit
/*
    for(i = 0; i < cfg->n_regs; i++) {
       uint32_t r = ad9520_read(dev, cfg->regs[i].addr);
       pp_printf("readback %x %x %x\n" , cfg->regs[i].addr , cfg->regs[i].value, r);
    }
*/

    return 0;
};

int ad9520_enable_output(struct ad9520_device *dev, int channel, int enabled )
{
    uint32_t val = enabled ? 0x64 : 0x65; // LVPECL
    ad9520_write(dev, 0xf0 + channel, val);
    ad9520_write(dev, 0x232, 0x01);  // commit
    return 0;
}

int ad9520_set_output_divider( struct ad9520_device *dev, int channel, int divider)
{
    int index = channel / 3;
    if( divider == 1 ) // undivided output
    {
        ad9520_write(dev, 0x190 + 3*index, 0);
        ad9520_write(dev, 0x191 + 3*index, 0x80); // bypass divider, ignore ysnc
        ad9520_write(dev, 0x192 + 3*index, 0);
    } else {
        int cyc = (divider / 2) - 1;

        if( cyc >= 8)
            return -1;

        ad9520_write(dev, 0x190 + 3*index, cyc | (cyc<<4));
        ad9520_write(dev, 0x191 + 3*index, 0x00); // enable divider, ignore ysnc
        ad9520_write(dev, 0x192 + 3*index, 0);
    }

    ad9520_write(dev, 0x232, 0x01);  // commit
    return 0;
}


