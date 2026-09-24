/*
 ** This work is part of the White Rabbit project
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
#include "dev/gpio.h"

#define GPIO_REG_COR 0
#define GPIO_REG_SOR 4
#define GPIO_REG_DDR 8
#define GPIO_REG_PSR 12

#define GPIO_BANK_SIZE 32

static void wb_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
  void *base = (void*)pin->device->priv;
  volatile uint32_t *dr = base + (GPIO_BANK_SIZE * (pin->pin >> 5)) + GPIO_REG_DDR;
  
  uint32_t mask = 1 << (pin->pin & 0x1f);

  if (dir)
    *dr |= mask;
  else
    *dr &= ~mask;
}

static void wb_gpio_out(const struct gpio_pin *pin, int value)
{
  void *base = (void*)pin->device->priv;
  volatile void *regs = base + (GPIO_BANK_SIZE * (pin->pin >> 5));

  uint32_t mask = 1 << (pin->pin & 0x1f);

  if(value)
    *(volatile uint32_t *)(regs + GPIO_REG_SOR) = mask;
  else
    *(volatile uint32_t *)(regs + GPIO_REG_COR) = mask;
}

static int wb_gpio_in(const struct gpio_pin *pin)
{
  void *base = (void*)pin->device->priv;
  volatile uint32_t *psr = base + (GPIO_BANK_SIZE * (pin->pin >> 5)) + GPIO_REG_PSR;
  uint32_t mask = 1 << (pin->pin & 0x1f);

  return (*psr & mask) ? 1 : 0;
}

int wb_gpio_create( struct gpio_device *device, uint32_t base_addr )
{
  device->priv = (void*) base_addr;
  device->set_dir = wb_gpio_set_dir;
  device->set_out = wb_gpio_out;
  device->read_pin = wb_gpio_in;

  return 1;
};

void gen_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
  if (!pin)
    return;
  if (!pin->device->set_dir)
    return;
  pin->device->set_dir(pin, dir);
}

void gen_gpio_out(const struct gpio_pin *pin, int value)
{
  if (!pin)
    return;
  if (!pin->device->set_out)
    return;

  pin->device->set_out(pin, value);
}

int gen_gpio_in(const struct gpio_pin *pin)
{
  if (!pin)
    return 0;
  if (!pin->device->read_pin)
    return 0;

  return pin->device->read_pin(pin);
}

void gen_gpio_bang(const struct gpio_pin *pin, int count)
{
  int i = 0 ;
  gen_gpio_out(pin, 0);
  for(i =0;i<count;i++)
  {
    gen_gpio_out(pin, 1);
    gen_gpio_out(pin, 0);
  }
}


