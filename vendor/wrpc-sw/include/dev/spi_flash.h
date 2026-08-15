/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2019 CERN (www.cern.ch)
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __SPI_FLASH_H
#define __SPI_FLASH_H

#include <stdint.h>

struct spi_bus;

#define SPI_FLASH_DEFAULT_BLOCKSIZE 65536

struct spi_flash_device 
{
    struct spi_bus *bus;
    uint32_t sector_size;
    uint32_t size;
    uint32_t cfg_entry;
    int use_4byte_addr;
};


void spi_flash_create(struct spi_flash_device *dev, struct spi_bus *bus, uint32_t sector_size, uint32_t cfg_entry);
int spi_flash_write(struct spi_flash_device *dev, uint32_t addr, uint8_t *buf, int count);
int spi_flash_read(struct spi_flash_device *dev, uint32_t addr, uint8_t *buf, int count);
uint32_t spi_flash_read_id(struct spi_flash_device *dev);
void spi_flash_erase_sector(struct spi_flash_device *dev, uint32_t addr);
int spi_flash_erase(struct spi_flash_device *dev, uint32_t addr, int count);
int spi_flash_get_sector_size(struct spi_flash_device *dev);

#endif
