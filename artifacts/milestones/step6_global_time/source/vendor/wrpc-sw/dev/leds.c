/*
 ** This work is part of the White Rabbit project
 *
 * Copyright (C) 2021 CERN (www.cern.ch)
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
#include <errno.h>

#include "dev/syscon.h"
#include "board.h"
#include "util.h"

#include "dev/gpio.h"
#include "dev/leds.h"

#ifdef BOARD_MAX_LEDS

static struct led_device *leds[BOARD_MAX_LEDS];

int led_create(struct led_device *led, struct gpio_pin *pin1, struct gpio_pin *pin2, int type, int default_state)
{
    int i;

    for (i = 0; i < BOARD_MAX_LEDS; i++)
        if (!leds[i])
        {
            
            leds[i] = led;
            led->pins[0] = pin1;
            led->pins[1] = pin2;
            led->type = type;
            led->state[0] = default_state;
            led->state[1] = default_state;
            return 0;
        }

    return -ENOMEM;
}

void led_action(struct led_device *led, int colors, int action)
{
    led->start_tics = timer_get_tics();

    if (colors & LED_COLOR_1)
    {
        led->state[0] = action;
    }
    if (colors & LED_COLOR_2)
    {
        led->state[1] = action;
    }
}

void led_set_blink_timing(struct led_device *led, int period, int period_on)
{
    led->blink_period = period;
    led->blink_period_on = period_on;
}

void leds_init()
{
    int i;
    for (i = 0; i < BOARD_MAX_LEDS; i++)
        leds[i] = NULL;
}

static void led_update_single(struct led_device *led)
{
    int n = (led->type & 0xf) == LED_TYPE_DUAL_COLOR ? 2 : 1;
    int i;

    for (i = 0; i < n; i++)
    {
        int32_t t = (timer_get_tics() - led->start_tics);

        switch (led->state[i])
        {
        case LED_ON:
            gen_gpio_out(led->pins[i], led->type & LED_TYPE_INVERT ? 0 : 1);
            break;
        case LED_OFF:
            gen_gpio_out(led->pins[i], led->type & LED_TYPE_INVERT ? 1 : 0);
            break;

        case LED_BLINK_SINGLE:
        {
            gen_gpio_out(led->pins[i], led->type & LED_TYPE_INVERT ? 0 : 1 );
            if( t > led->blink_period )
                led->state[i] = LED_OFF;
            break;
        }
        case LED_BLINK_SINGLE_NEGATIVE:
        {
            gen_gpio_out(led->pins[i], led->type & LED_TYPE_INVERT ? 1 : 0 );
            if( t > led->blink_period )
                led->state[i] = LED_ON;
            break;
        }
        case LED_BLINK:
        {
            int v;

            if( led->blink_period == 0 )
                break;

	    t %= led->blink_period;
	    v = t < led->blink_period_on ? 1 : 0;
	    if (led->type & LED_TYPE_INVERT)
                    v = 1 - v;

	    gen_gpio_out(led->pins[i], v);

            break;
        }

        default:
            break;
        }
    }
}

void leds_update()
{
    int i;
    for (i = 0; i < BOARD_MAX_LEDS; i++)
        if (leds[i])
            led_update_single(leds[i]);
}
#endif /* BOARD_MAX_LEDS */
