/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#ifndef __FRAM_H_
#define __FRAM_H_

#include <stdint.h>
struct fram_device {
    struct spi_bus *bus;
};

extern struct fram_device wrc_fram_dev;

/* Fram interface functions */
void fram_init(struct fram_device *dev, struct spi_bus *bus );
int fram_write(struct fram_device *dev, uint32_t addr, uint8_t *buf, int count);
int fram_read(struct fram_device *dev, uint32_t addr, uint8_t *buf, int count);
int fram_erase(struct fram_device *dev, uint32_t addr, int count);

/* SDB flash interface functions */
int fram_sdb_check(void);

#endif // __FRAM_H_
