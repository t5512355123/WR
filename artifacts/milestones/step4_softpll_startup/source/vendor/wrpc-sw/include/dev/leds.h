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

#ifndef __LEDS_H
#define __LEDS_H

#include <stdint.h>

struct gpio_pin;

#define LED_TYPE_SINGLE_COLOR 1
#define LED_TYPE_DUAL_COLOR 2

#define LED_TYPE_INVERT ( 1<<4 )

#define LED_ON 0
#define LED_OFF 1
#define LED_BLINK 2
#define LED_BLINK_SINGLE (1<<4)
#define LED_BLINK_SINGLE_NEGATIVE (1<<5)

#define LED_COLOR_1 (1<<0)
#define LED_COLOR_2 (1<<1)
#define LED_COLOR_BOTH ( (1<<0)|(1<<1) )

struct led_device
{
    uint8_t type;
    uint8_t state[2];
    uint8_t color;
    uint16_t blink_period_on;
    uint16_t blink_period;
    uint32_t start_tics;
    struct gpio_pin* pins[2];
};


int led_create( struct led_device* led, struct gpio_pin* pin1, struct gpio_pin* pin2, int type, int default_state );
void led_action( struct led_device *led, int colors, int action );
void led_set_blink_timing( struct led_device *led, int period, int period_on );

void leds_init(void);
void leds_update(void);

#endif
