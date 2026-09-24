/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011,2012 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include "board.h"
#include "dev/syscon.h"
#include "dev/bb_i2c.h"
#include "dev/gpio.h"
#include "pp-printf.h"

#include <errno.h>

void bb_i2c_delay(uint32_t delay)
{
	int i;
	for (i = 0; i < delay; i++)
		asm volatile ("nop");
}

#define M_SDA_OUT(x) { gen_gpio_out( bus->pin_sda, x); bb_i2c_delay(bus->loop_delay); }
#define M_SCL_OUT(x) { gen_gpio_out( bus->pin_scl, x); bb_i2c_delay(bus->loop_delay); }
#define M_SDA_IN gen_gpio_in(bus->pin_sda)

void bb_i2c_start(const struct i2c_bus *bus)
{
	M_SDA_OUT(0);
	M_SCL_OUT(0);
}

void bb_i2c_repeat_start(const struct i2c_bus *bus)
{
	M_SDA_OUT(1);
	M_SCL_OUT(1);
	M_SDA_OUT(0);
	M_SCL_OUT(0);
}

void bb_i2c_stop(const struct i2c_bus *bus)
{
	M_SDA_OUT(0);
	M_SCL_OUT(1);
	M_SDA_OUT(1);
}

int bb_i2c_put_byte(const struct i2c_bus *bus, uint8_t data)
{
	int i;
	int ack;

	for (i = 0; i < 8; i++, data <<= 1) {
		M_SDA_OUT(data & 0x80);
		M_SCL_OUT(1);
		M_SCL_OUT(0);
	}

	M_SDA_OUT(1);
	M_SCL_OUT(1);

	ack = M_SDA_IN;	/* ack: sda is pulled low -> success.     */
	M_SCL_OUT(0);
	M_SDA_OUT(0);

	return ack == 0 ? 0 : -ENODEV;
}

void bb_i2c_get_byte(const struct i2c_bus *bus, uint8_t *data, int last)
{

	int i;
	uint8_t indata = 0;

	M_SDA_OUT(1);
	/* assert: scl is low */
	M_SCL_OUT(0);

	for (i = 0; i < 8; i++) {
		M_SCL_OUT(1);
		indata <<= 1;
		if (M_SDA_IN)
			indata |= 0x01;
		M_SCL_OUT(0);
	}

	if (last) {
		M_SDA_OUT(1);	//noack
		M_SCL_OUT(1);
		M_SCL_OUT(0);
	} else {
		M_SDA_OUT(0);	//ack
		M_SCL_OUT(1);
		M_SCL_OUT(0);
	}

	*data = indata;
}

void bb_i2c_create(struct i2c_bus *bus,
		    const struct gpio_pin *pin_scl,
		    const struct gpio_pin *pin_sda )
{
	bus->pin_scl = pin_scl;
	bus->pin_sda = pin_sda;
	bus->loop_delay = 100;
}

void bb_i2c_init(const struct i2c_bus *bus)
{
	M_SCL_OUT(1);
	M_SDA_OUT(1);
}

int bb_i2c_devprobe(const struct i2c_bus *bus, uint8_t i2c_addr)
{
	int ret;
	bb_i2c_start(bus);
	ret = !bb_i2c_put_byte(bus, i2c_addr << 1);
	bb_i2c_stop(bus);

	return ret;
}

void bb_i2c_scan(const struct i2c_bus *bus)
{
    int i;

	pp_printf("Scan\n");
	for (i=0; i<0x80; i++) {
    	 bb_i2c_start(bus);
		if (!bb_i2c_put_byte(bus, i<<1))
			pp_printf("found : %x\n", i);
     	bb_i2c_stop(bus);
    }
}
