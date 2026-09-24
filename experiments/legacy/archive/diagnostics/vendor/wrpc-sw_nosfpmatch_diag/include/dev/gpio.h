#ifndef __GPIO_H
#define __GPIO_H

#include <stdint.h>

struct gpio_pin;

typedef void (*set_dir_func)(const struct gpio_pin *, int);
typedef void (*set_out_func)(const struct gpio_pin *, int);
typedef int (*read_pin_func)(const struct gpio_pin *);

struct gpio_device
{
    void* priv;
    set_dir_func set_dir;
    set_out_func set_out;
    read_pin_func read_pin;
};

struct gpio_pin
{
    const struct gpio_device *device;
    int pin;
};



int wb_gpio_create( struct gpio_device *device, uint32_t base_addr );
void gen_gpio_set_dir(const struct gpio_pin *pin, int dir);
void gen_gpio_out(const struct gpio_pin *pin, int value);
int gen_gpio_in(const struct gpio_pin *pin);
void gen_gpio_bang(const struct gpio_pin *pin, int count);

#endif
