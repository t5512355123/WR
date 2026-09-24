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
#include "dev/syscon.h"
#include "dev/gpio.h"
#include "dev/bb_spi.h"
#include "dev/ad7888.h"

static int first_bit_set_after(uint32_t mask, int n)
{
    int i;

    if (!mask)
        return 0;

    for (i = (n + 1) % 32; i < 32; i++)
    {

        if (mask & (1 << i))
            return i;
    }

    for (i = 0; i < n; i++)
    {
        if (mask & (1 << i))
            return i;
    }

    return -1;
}

int ad7888_create( struct ad7888_device *dev, struct spi_bus *bus )
{
    dev->bus = bus;
    dev->channel_valid = 0;
    dev->current_ch = 0;
    dev->conversion_pending = 0;
    return 0;
}

void ad7888_start_conversion( struct ad7888_device *dev, uint16_t channel_mask )
{
    uint64_t dummy;

    dev->channel_mask = channel_mask;
    dev->channel_valid = 0;
    dev->current_ch = -1;
    tmo_init( &dev->poll_tmo, 1 );
    dev->conversion_pending = 1;

    int ch = first_bit_set_after( dev->channel_mask, dev->current_ch );

    //pp_printf("sc %d %d %x\n", ch, dev->current_ch, dev->channel_mask );

    if( ch < 0 )
        return;

    dev->current_ch = ch;

    bb_spi_cs( dev->bus, 1 );
    bb_spi_xfer( dev->bus, (ch << (3 + 8)), &dummy, 16);
    bb_spi_cs( dev->bus, 0 );
}

int ad7888_poll( struct ad7888_device *dev )
{
    uint64_t rv;

    if( !dev->conversion_pending )
        return dev->channel_valid;
    if( !dev->channel_mask )
        return 0;
    if( !tmo_expired( &dev->poll_tmo ) )
        return 0;

    int next_ch = first_bit_set_after( dev->channel_mask, dev->current_ch );


    bb_spi_cs( dev->bus, 1 );
    bb_spi_xfer( dev->bus, (next_ch << (3 + 8)), &rv, 16);
    bb_spi_cs( dev->bus, 0);

    tmo_restart( &dev->poll_tmo );
    dev->channel[ dev->current_ch ] = rv & 0xffff;

    dev->channel_valid |= (1 << dev->current_ch);
    dev->current_ch = next_ch;

    if( next_ch < 0 )
        dev->conversion_pending = 0;

    return dev->channel_valid;
}

int ad7888_meas_channel( struct ad7888_device *dev, int ch )
{
    ad7888_start_conversion( dev, (1<<ch));
    while( (ad7888_poll(dev) & (1<<ch)) == 0 );
    return dev->channel[ch];
}
