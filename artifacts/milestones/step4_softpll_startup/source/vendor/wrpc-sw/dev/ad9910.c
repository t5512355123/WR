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
#include <stdio.h>

#include "pp-printf.h"
#include "wrc-debug.h"
#include "dev/gpio.h"
#include "dev/bb_spi.h"
#include "dev/ad9910.h"

#define AD9910_REF_FREQ ( 1000000000ULL ) // 1 GHz

static struct ad9910_config_reg ad9910_default_config[] = {
    {0, 0x02000002 | (1<<13), 32},              // CFR1, unidir mode for SDIO, autoclear phase accumulator on IOUPDATE
    {1, 0x00000800, 32},              // CFR2, TW - enabled sync pulse timing validation
    {2, 0x1f3fc000, 32},              // CFR3: no PLL
    {3, 0x00000064, 32},              // Aux DAC control: DAC Full scale current
    {4, 0xffffffff, 32},              // IO update rate
    {7, 0x00000000, 32},              // default FTW
    {8, 0x0000, 16},                  // default phase offset
    {9, 0x00000000, 32},              // amplitude scale factors
    {0xa, 0x00000000, 32},            // multichip sync
    {0xe, 0x08b5000039374bc7ULL, 64}, // profile 0: 223.5 MHz, 0 deg phi, ASF 0.13
    {-1, 0, 0}};

uint64_t ad9910_read(struct ad9910_device *dev, uint32_t reg, int nbits)
{
    uint64_t rv;
    bb_spi_cs(dev->bus, 1);
    bb_spi_write( dev->bus, reg | 0x80, 8);
    rv = bb_spi_read(dev->bus, nbits);
    bb_spi_cs(dev->bus, 0);
    return rv;
}

void ad9910_write(struct ad9910_device *dev, uint32_t reg, uint64_t value, int nbits)
{
    bb_spi_cs(dev->bus, 1);
    bb_spi_write( dev->bus, reg, 8);
    bb_spi_write( dev->bus, value, nbits);
    bb_spi_cs(dev->bus, 0);
}

void ad9910_trigger_update(struct ad9910_device *dev)
{
    dev->trigger_io_update(dev);
}

#define AD9910_REG_CFR1 1
#define AD9910_DEFAULT_CFR1  0x400820

int ad9910_probe( struct ad9910_device *dev, struct spi_bus *bus, void (*trigger_io_update)(struct ad9910_device *dev) )
{
    dev->bus = bus;
    dev->trigger_io_update = trigger_io_update;

    bb_spi_cs(dev->bus, 0);

    ad9910_write( dev, 0, 0x02000002, 32); // unidir mode for SDIO
    ad9910_trigger_update( dev );

    uint32_t id = ad9910_read( dev, AD9910_REG_CFR1, 32 );
    dev_dbg("AD9910 ID[%p]: 0x%x (expected 0x%x)\n", dev, id, AD9910_DEFAULT_CFR1 );

    return (id == AD9910_DEFAULT_CFR1) ? 0 : -1;
}

uint64_t ad9910_frequency_to_ftw( uint64_t freq_hz )
{
    return  (1ULL << 32) * freq_hz / AD9910_REF_FREQ;
}

uint64_t ad9910_ftw_to_frequency( uint64_t ftw )
{
    return  (ftw * (uint64_t) AD9910_REF_FREQ ) >> 32;
}

int ad9910_program( struct ad9910_device *dev, uint64_t ftw_n, int phase, int fs_current )
{
    int i;

    // formula (2) from AD9910 datasheet, page 22

    uint64_t ftw = ftw_n;
    uint64_t prof0_cr = ftw | (0x8b5ULL << 48); 

    dev_dbg("ad9910 FTW = %d\n", (uint32_t) ftw);

//    dev_dbg("ad9910_program [%08x%08x] asf %d!\n", (uint32_t)(prof0_cr >> 32), (uint32_t)prof0_cr, asf );

    for(i = 0; ad9910_default_config[i].addr >= 0; i++)
    {
        struct ad9910_config_reg r = ad9910_default_config[i];

        if(r.addr == 3)
        {
            r.value &= 0xffffff00ULL;
            r.value |= (uint64_t) fs_current;     // Aux DAC control: DAC Full scale current
        } else
        if( r.addr == 0xe ) // profile 0
            r.value = prof0_cr;

        ad9910_write( dev, r.addr, r.value, r.nbits );
    }

    ad9910_trigger_update( dev );
    return 0;
}

#define AD9910_SYNC_VERIF_DELAY_TAPS 0

void ad9910_configure_sync( struct ad9910_device *dev, int enable, int fine_delay_taps )
{
    uint32_t r10 = ((fine_delay_taps & 0x1f) << 3)
                    | (enable ? ( 1<<27) : 0)
                    | (AD9910_SYNC_VERIF_DELAY_TAPS << 28) | (1<<26);

    ad9910_write( dev, 0xa, 0 , 32 );
    ad9910_write( dev, 0x1, 0x00000820, 32);              // CFR2, TW - enabled sync pulse timing validation
    ad9910_trigger_update( dev );

    ad9910_write( dev, 0x1, 0x00000800, 32);              // CFR2, TW - enabled sync pulse timing validation
    ad9910_write( dev, 0xa, r10 , 32 );
    ad9910_trigger_update( dev );
}

void ad9910_enable_external_ioupdate( struct ad9910_device *dev, int enable )
{
    uint64_t cfr2 = ad9910_read(dev, 1, 32 );

    pp_printf("CFR2 = 0x%08x\n", (unsigned) cfr2 );

    if( enable )
        cfr2 &= ~ (1<<23);
    else
        cfr2 |= (1<<23);

    ad9910_write( dev, 1, cfr2, 32 );
}
