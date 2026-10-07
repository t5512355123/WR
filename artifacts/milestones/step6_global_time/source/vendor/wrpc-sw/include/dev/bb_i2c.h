/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __BB_I2C_H
#define __BB_I2C_H

#include <stdint.h>

#define BB_I2C_WRITE 1

struct i2c_bus
{
    const struct gpio_pin *pin_scl;
    const struct gpio_pin *pin_sda;
    int loop_delay;
};

int bb_i2c_devprobe(const struct i2c_bus *bus, uint8_t i2c_addr);
void bb_i2c_create(struct i2c_bus *bus, const struct gpio_pin *pin_scl, const struct gpio_pin *pin_sda );
void bb_i2c_init(const struct i2c_bus *bus);
void bb_i2c_start(const struct i2c_bus *bus);
void bb_i2c_repeat_start(const struct i2c_bus *bus);
void bb_i2c_stop(const struct i2c_bus *bus);
void bb_i2c_get_byte(const struct i2c_bus *bus, uint8_t *data, int last);
int bb_i2c_put_byte(const struct i2c_bus *bus, uint8_t data);
void bb_i2c_delay(uint32_t delay);
void bb_i2c_scan(const struct i2c_bus *bus);

#endif
