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
#include <sys/errno.h>

#include "dev/si57x.h"

#include "hw/si570_if_wb.h"

#include <wrc-debug.h>
#include <hw/rawmem.h>
#include "dev/syscon.h"

#define SI57X_PIN_SCL 0
#define SI57X_PIN_SDA 1

void si57x_gpio_out(const struct gpio_pin *pin, int value)
{
	struct wr_si57x_interface_device* dev = ( struct wr_si57x_interface_device* ) pin->device->priv;



	uint32_t mask = (pin->pin == SI57X_PIN_SCL ? SI570_GPCR_SCL : SI570_GPCR_SDA );
	uint32_t reg = (value ? SI570_REG_GPSR : SI570_REG_GPCR );


	writel( mask, dev->base_addr + reg );
}


void si57x_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
	si57x_gpio_out(pin, !dir);
}


int si57x_gpio_in(const struct gpio_pin *pin)
{
	struct wr_si57x_interface_device* dev = ( struct wr_si57x_interface_device* ) pin->device->priv;

	uint32_t gpsr = readl( dev->base_addr + SI570_REG_GPSR );

	if ( pin->pin == SI57X_PIN_SCL )
		return (gpsr & SI570_GPSR_SCL ? 1 : 0);
	else
		return (gpsr & SI570_GPSR_SDA ? 1 : 0);
}

void si57x_read( struct wr_si57x_interface_device *dev, uint8_t addr, uint8_t *data, int count )
{
	int i;

	bb_i2c_start( &dev->master );
	bb_i2c_put_byte( &dev->master, dev->i2c_addr << 1 );
	bb_i2c_put_byte( &dev->master, addr );
	bb_i2c_repeat_start( &dev->master );
	bb_i2c_put_byte( &dev->master, (dev->i2c_addr << 1) | 1 );

	for(i = 0; i < count; i ++)
		bb_i2c_get_byte( &dev->master, &data[i], i == (count - 1) ? 1 : 0 );

	bb_i2c_stop( &dev->master );
}


void si57x_write( struct wr_si57x_interface_device *dev, uint8_t addr, uint8_t *data, int count )
{
	int i;

	bb_i2c_start( &dev->master );
	bb_i2c_put_byte( &dev->master, dev->i2c_addr << 1 );
	bb_i2c_put_byte( &dev->master, addr );

	for(i = 0; i < count; i ++)
	{
		bb_i2c_put_byte( &dev->master, data[i] );
	}

	bb_i2c_stop( &dev->master );
}

void si57x_get_xtal_frequency( struct wr_si57x_interface_device *dev, uint32_t* freq_hz )
{
	uint8_t regs[16];

	si57x_read( dev, 7, regs, 9 ); // R7... R15

	uint64_t rfreq = ( (uint64_t) regs[12-7] ) | // R12
					 ( ( (uint64_t) regs[11-7]) << 8 ) | // R11
					 ( ( (uint64_t) regs[10-7]) << 16 ) | // R10
					 ( ( (uint64_t) regs[9-7]) << 24 ) | // R9
					 ( ( (uint64_t) regs[8-7] & 0x3f) << 32 ); // R8

	uint64_t n1 = ( ( (regs[0] & 0x1f) << 2) | (regs[1] >> 6) ) + 1;
	uint64_t hs_div = (regs[0] >> 5) + 4;

	board_dbg("Si57x: RFREQ %08x %08x n1 %d hsdiv %d\n", (uint32_t) (rfreq >> 32), (uint32_t) rfreq, (int)n1, (int)hs_div );

	if( rfreq == 0 )
	{
		board_dbg("strange, rfreq == 0\n");
		return;
	}

	uint64_t f0 = 100000000;
	uint64_t f_xtal = (f0 * hs_div * n1 ) * ( 1ULL << 28 ) / rfreq;


	board_dbg("Si57x: xtal frequency = %d Hz\n", (int) f_xtal );

	if( freq_hz )
		*freq_hz = f_xtal;

}

int si57x_calc_frequency( uint32_t f_xtal, uint32_t freq_hz, uint64_t *rfreq_out, int* hsdiv_out, int* n1_out )
{
	const uint8_t hsdiv_values[] = { 4, 5, 6, 7, 9, 11, 0 };
	int hsdiv_idx, n1;
	const uint64_t f_dco_min = 4850000000;
	const uint64_t f_dco_max = 5670000000;

		for( hsdiv_idx = 0; hsdiv_values[hsdiv_idx] != 0; hsdiv_idx++ )
		{
			for( n1 = 1; n1 <= 255; n1++ )
			{
				if ( n1 && (n1 & 1) )
					continue;

			uint64_t hs_div = hsdiv_values[hsdiv_idx];

			uint64_t f_dco = (uint64_t) freq_hz * hs_div * n1;

			if( f_dco < f_dco_min || f_dco > f_dco_max )
				continue;

			uint64_t rfreq = f_dco * (1ULL<<28) / f_xtal;

			*rfreq_out = rfreq;
			*hsdiv_out = hsdiv_idx;
			*n1_out = n1;

			board_dbg("Si57x: New RFREQ %08x %08x n1 %d hsdiv %d\n", (uint32_t) (*rfreq_out >> 32), (uint32_t) *rfreq_out, (int)*n1_out, (int)*hsdiv_out );

			//found = 1;
			return 0;
		}
	}
	return -1;
}

void si57x_reset(struct wr_si57x_interface_device *dev )
{
	uint8_t r135 = 1;

	r135 = (1<<7);
	si57x_write( dev, 135, &r135, 1 );
	timer_delay_ms(10);
	r135 =  1;
	si57x_write( dev, 135, &r135, 1 );

}


int si57x_set_frequency( struct wr_si57x_interface_device *dev, uint32_t f_xtal, uint32_t freq_hz, int vco_gain )
{
	uint8_t regs[16];
	uint64_t rfreq;
	int hsdiv;
	int n1;

	if( si57x_calc_frequency ( f_xtal, freq_hz, &rfreq, &hsdiv, &n1 ) < 0 )
		return -1;

	dev->n1 = n1;
	dev->hsdiv = hsdiv;
	dev->rfreq = rfreq;

	regs[12] = (dev->rfreq & 0xff);
	regs[11] = ((dev->rfreq >> 8) & 0xff);
	regs[10] = ((dev->rfreq >> 16) & 0xff);
	regs[9] =  ((dev->rfreq >> 24) & 0xff);
	regs[8] = ((dev->rfreq >>32) & 0x3f) | (((dev->n1-1) & 0xff) << 6);
	regs[7] = (dev->hsdiv << 5) | ((dev->n1-1) >> 2);

	board_dbg("Si57x: New RFREQ %08x %08x n1 %d hsdiv %d\n", (uint32_t) (dev->rfreq >> 32), (uint32_t) dev->rfreq, (int)dev->n1, (int)dev->hsdiv );


	uint8_t r137, r135;

	timer_delay_ms(10);

	board_dbg("Si57x: VCO Gain=%d\n", vco_gain);

	writel( (uint32_t) ( rfreq & 0xffffffffULL), dev->base_addr + SI570_REG_RFREQL );
	writel( (uint32_t) ( rfreq >> 32) | (((n1-1) & 0xff) << 8) | (hsdiv << 16), dev->base_addr + SI570_REG_RFREQH );
	writel( SI570_CR_ENABLE | SI570_CR_CLK_DIV_W(200) | SI570_CR_I2C_ADDR_W ( ( dev->i2c_addr << 1 ) ) | SI570_CR_GAIN_W(vco_gain), dev->base_addr + SI570_REG_CR );

	si57x_read( dev, 135, &r135, 1 );
	si57x_read( dev, 137, &r137, 1 );
	r137 |= (1<<4); // freeze DCO
	si57x_write( dev, 137, &r137, 1);
	si57x_write( dev, 7, regs + 7, 6 );
	r137 &= ~(1<<4); // unfreeze DCO
	si57x_write( dev, 137, &r137, 1);
	r135 |= (1<<6); // assert NewFreq
	si57x_write( dev, 135, &r135, 1);

	return 0;
}


void wr_si57x_interface_init( struct wr_si57x_interface_device *dev, uint32_t base_addr, uint8_t i2c_addr )
{

	dev->base_addr = (void *) base_addr;
	dev->gpio_i2c.priv = (void *) dev;
	dev->gpio_i2c.read_pin = si57x_gpio_in;
	dev->gpio_i2c.set_dir = si57x_gpio_set_dir;
	dev->gpio_i2c.set_out = si57x_gpio_out;
	dev->i2c_addr = i2c_addr;
	dev->pin_scl.device = &dev->gpio_i2c;
	dev->pin_scl.pin = SI57X_PIN_SCL;
	dev->pin_sda.device = &dev->gpio_i2c;
	dev->pin_sda.pin = SI57X_PIN_SDA;
	bb_i2c_create( &dev->master, &dev->pin_scl, &dev->pin_sda );
}
