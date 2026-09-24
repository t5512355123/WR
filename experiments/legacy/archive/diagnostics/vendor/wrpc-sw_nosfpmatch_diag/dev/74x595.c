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
#include "wrc-debug.h"
#include "dev/syscon.h"
#include "dev/gpio.h"
#include "dev/74x595.h"

#define X595_GPIO_MAX 3

struct x595_gpio_priv_data
{
    struct gpio_pin *pin_rclk;
    struct gpio_pin *pin_srclk;
    struct gpio_pin *pin_srclr_n;
    struct gpio_pin *pin_ser;
    int n_regs;
    uint32_t cur_data;
};

static int  x595_gpio_priv_count = 0;
static struct x595_gpio_priv_data x595_gpio_priv[X595_GPIO_MAX];

static int x595_gpio_in(const struct gpio_pin *pin)
{
    struct x595_gpio_priv_data *priv = (struct x595_gpio_priv_data *)pin->device->priv;
    return priv->cur_data & (1 << pin->pin) ? 1 : 0;
}

static void x595_gpio_out(const struct gpio_pin *pin, int value);

#if 0
void x595_test(struct gpio_device *device)
{
    struct x595_gpio_priv_data *priv = (struct x595_gpio_priv_data *)device->priv;
    int i = 0, j = 0;
    struct gpio_pin p;
    p.device = device;
    
    for(;;)
    {
    /*    i++;
        gen_gpio_out(priv->pin_ser, 0);  // shift out the bit

        gen_gpio_out(priv->pin_ser, i % 2);  // shift out the bit

        for(j = 0; j < 24; j++)
        {
            gen_gpio_out(priv->pin_srclk, 0); // pulse the serial clock
            gen_gpio_out(priv->pin_srclk, 1);
            gen_gpio_out(priv->pin_srclk, 0);

            gen_gpio_out(priv->pin_ser, 0);  // shift out the bit
        }

        gen_gpio_out(priv->pin_rclk, 0);
        gen_gpio_out(priv->pin_rclk, 1); // pass the shift reg contents to the output latch
        gen_gpio_out(priv->pin_rclk, 0);*/
        i++;
        pp_printf("T %d\n", i % 2);
        p.pin = 8;
        x595_gpio_out( &p, 0 );
        x595_gpio_out( &p, 1 );
        x595_gpio_out( &p, 0 );
        p.pin = 9;
        x595_gpio_out( &p, 0 );
        x595_gpio_out( &p, 1 );
        x595_gpio_out( &p, 0 );
    }
}
#endif

static void x595_gpio_sync_out(const struct x595_gpio_priv_data *priv)
{
    int i, nbits = priv->n_regs * 8;

    gen_gpio_out(priv->pin_srclr_n, 0); // reset the shift register
    gen_gpio_out(priv->pin_srclr_n, 1);

    for(i = 0; i < nbits; i++)
    {
        gen_gpio_out(priv->pin_ser, (priv->cur_data & (1 << (nbits - 1 - i))) ? 1 : 0);  // shift out the bit
        gen_gpio_out(priv->pin_srclk, 0); // pulse the serial clock
        gen_gpio_out(priv->pin_srclk, 1);
        gen_gpio_out(priv->pin_srclk, 0);
    }

    gen_gpio_out(priv->pin_rclk, 1); // pass the shift reg contents to the output latch
    gen_gpio_out(priv->pin_rclk, 0);
}


static void x595_gpio_out(const struct gpio_pin *pin, int value)
{
    struct x595_gpio_priv_data *priv = (struct x595_gpio_priv_data *)pin->device->priv;

    if (value)
        priv->cur_data |= (1 << pin->pin);
    else
        priv->cur_data &= ~(1 << pin->pin);

    x595_gpio_sync_out( priv );
}

int x595_gpio_create(struct gpio_device *device, int n_regs, const struct gpio_pin *pin_rclk, const struct gpio_pin *pin_srclk, struct gpio_pin *pin_srclr_n, const struct gpio_pin *pin_ser)
{
    struct x595_gpio_priv_data *priv;
    if( x595_gpio_priv_count >= X595_GPIO_MAX )
        return -1;

    dev_dbg("x595_gpio_create: this = %p, n_regs = %d\n", device, n_regs );

    device->priv = priv = &x595_gpio_priv[x595_gpio_priv_count];
    x595_gpio_priv_count++;

    priv->pin_rclk = (struct gpio_pin *) pin_rclk;
    priv->pin_srclk = (struct gpio_pin *) pin_srclk;
    priv->pin_srclr_n = (struct gpio_pin *) pin_srclr_n;
    priv->pin_ser = (struct gpio_pin *) pin_ser;
    priv->cur_data = 0;
    priv->n_regs = n_regs;

    gen_gpio_out(priv->pin_rclk, 0);  // reset the shift register
    gen_gpio_out(priv->pin_srclk, 0); // reset the shift register

    gen_gpio_out(priv->pin_srclr_n, 0); // reset the shift register
    usleep(1);
    gen_gpio_out(priv->pin_srclr_n, 1);

    x595_gpio_sync_out(device->priv);

    device->set_dir = NULL;
    device->set_out = x595_gpio_out;
    device->read_pin = x595_gpio_in;

    return 0;
};
