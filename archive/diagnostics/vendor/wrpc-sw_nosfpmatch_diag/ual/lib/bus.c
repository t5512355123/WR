/**
 * @copyright Copyright (c) 2016 CERN
 * @author: Federico Vaga <federico.vaga@cern.ch>
 * @license: GPLv3
 */

#include <unistd.h>
#include <errno.h>
#include "ual-int.h"

/**
 * It writes 64bit values at consecutive addresses starting from the given one
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data values to write
 * @param[in] n number of values to write
 */
void ual_writell_n(struct ual_bar_tkn *dev, uint32_t addr, uint64_t *data,
		  unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	uint64_t value;
	int i;

	for (i = 0; i < n; ++i, ++data) {
		value = *data;
		if ((bar->flags & UAL_BAR_FLAGS_DEVICE_BE) !=
		    (bar->flags & UAL_BAR_FLAGS_HOST_BE)) {
			/* if original endianess and target one are not
			   compatible, do the swap byte order */
			value = ((value >> 56) & 0x00000000000000ff) |
				((value >> 40) & 0x000000000000ff00) |
				((value >> 24) & 0x0000000000ff0000) |
				((value >>  8) & 0x00000000ff000000) |
				((value <<  8) & 0x000000ff00000000) |
				((value << 24) & 0x0000ff0000000000) |
				((value << 40) & 0x00ff000000000000) |
				((value << 56) & 0xff00000000000000);
		}
		*(volatile uint64_t *) (bar->ptr + addr + (i * 8)) = value;
	}
}


/**
 * It writes a 64bit value at the given address
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data value to write
 */
void ual_writell(struct ual_bar_tkn *dev, uint32_t addr, uint64_t data)
{
	ual_writell_n(dev, addr, &data, 1);
}


/**
 * It writes 32bit values at consecutive addresses starting from the given one
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data values to write
 * @param[in] n number of values to write
 */
void ual_writel_n(struct ual_bar_tkn *dev, uint32_t addr, uint32_t *data,
		  unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	uint32_t value;
	int i;

	for (i = 0; i < n; ++i, ++data) {
		value = *data;
		if ((bar->flags & UAL_BAR_FLAGS_DEVICE_BE) !=
		    (bar->flags & UAL_BAR_FLAGS_HOST_BE)) {
			/* if original endianess and target one are not
			   compatible, do the swap byte order */
			value = ((value >> 24) & 0xff) |
				((value << 8) & 0xff0000) |
				((value >> 8) & 0xff00) |
				((value << 24) & 0xff000000);
		}
		*(volatile uint32_t *) (bar->ptr + addr + (i * 4)) = value;
	}
}


/**
 * It writes a 32bit value at the given address
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data value to write
 */
void ual_writel(struct ual_bar_tkn *dev, uint32_t addr, uint32_t data)
{
	ual_writel_n(dev, addr, &data, 1);
}


/**
 * It writes 16bit values at consecutive addresses starting from the given one
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data values to write
 * @param[in] n number of values to write
 */
void ual_writew_n(struct ual_bar_tkn *dev, uint32_t addr, uint16_t *data,
		  unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	uint16_t value;
	int i;

	for (i = 0; i < n; ++i, ++data) {
		value = *data;
		if ((bar->flags & UAL_BAR_FLAGS_DEVICE_BE) !=
		    (bar->flags & UAL_BAR_FLAGS_HOST_BE)) {
			/* if original endianess and target one are not
			   compatible, do the swap byte order */
			value = ((value >> 8) & 0x00ff) |
				((value << 8) & 0xff00);
		}
		*(volatile uint16_t *) (bar->ptr + addr + (i * 2)) = value;
	}
}


/**
 * It writes a 16bit value at the given address.
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data value to write
 */
void ual_writew(struct ual_bar_tkn *dev, uint32_t addr, uint16_t data)
{
	ual_writew_n(dev, addr, &data, 1);
}


/**
 * It writes 8bit values at consecutive addresses starting from the given one
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data values to write
 * @param[in] n number of values to write
 */
void ual_writeb_n(struct ual_bar_tkn *dev, uint32_t addr, uint8_t *data,
		  unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	uint8_t value;
	int i;

	for (i = 0; i < n; ++i, ++data) {
		value = *data;
		*(volatile uint8_t *) (bar->ptr + addr + i) = value;
	}
}


/**
 * It writes an 8bit value at the given address.
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[in] data value to write
 */
void ual_writeb(struct ual_bar_tkn *dev, uint32_t addr, uint8_t data)
{
	ual_writeb_n(dev, addr, &data, 1);
}


/**
 * It reads a given number of 64bit values
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[out] data preallocated buffer where store data
 * @param[in] n number of values to read
 */
void ual_readll_n(struct ual_bar_tkn *dev, uint32_t addr,
		 uint64_t *data, unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	int i;

	for (i = 0; i < n; ++i, addr += 8) {
		data[i] = *(volatile uint64_t *) (bar->ptr + addr);

		if ((bar->flags & UAL_BAR_FLAGS_DEVICE_BE) !=
		    (bar->flags & UAL_BAR_FLAGS_HOST_BE)) {
			/* if original endianess and target one are not
			   compatible, do the swap byte order */
			data[i] = ((data[i] >> 56) & 0x00000000000000ff) |
				((data[i] >> 40) & 0x000000000000ff00) |
				((data[i] >> 24) & 0x0000000000ff0000) |
				((data[i] >>  8) & 0x00000000ff000000) |
				((data[i] <<  8) & 0x000000ff00000000) |
				((data[i] << 24) & 0x0000ff0000000000) |
				((data[i] << 40) & 0x00ff000000000000) |
				((data[i] << 56) & 0xff00000000000000);
		}
	}
}


/**
 * It reads a 64bit value from the given address.
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @return it returns a 64bit value
 */
uint64_t ual_readll(struct ual_bar_tkn *dev, uint32_t addr)
{
	uint64_t data;

	ual_readll_n(dev, addr, &data, 1);

	return data;
}


/**
 * It reads a given number of 32bit values
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[out] data preallocated buffer where store data
 * @param[in] n number of values to read
 */
void ual_readl_n(struct ual_bar_tkn *dev, uint32_t addr,
		 uint32_t *data, unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	int i;

	for (i = 0; i < n; ++i, addr += 4) {
		data[i] = *(volatile uint32_t *) (bar->ptr + addr);

		if ((bar->flags & UAL_BAR_FLAGS_DEVICE_BE) !=
		    (bar->flags & UAL_BAR_FLAGS_HOST_BE)) {
			/* if original endianess and target one are not
			   compatible, do the swap byte order */
			data[i] = ((data[i] >> 24) & 0xff) |
				((data[i] << 8) & 0xff0000) |
				((data[i] >> 8) & 0xff00) |
				((data[i] << 24) & 0xff000000);
		}
	}
}


/**
 * It reads a 32bit value from the given address.
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @return it returns a 32bit value
 */
uint32_t ual_readl(struct ual_bar_tkn *dev, uint32_t addr)
{
	uint32_t data;

	ual_readl_n(dev, addr, &data, 1);

	return data;
}


/**
 * It reads a given number of 16bit values
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[out] data preallocated buffer where store data
 * @param[in] n number of values to read
 */
void ual_readw_n(struct ual_bar_tkn *dev, uint32_t addr,
		 uint16_t *data, unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	int i;

	for (i = 0; i < n; ++i, addr += 2) {
		data[i] = *(volatile uint16_t *) (bar->ptr + addr);

		if ((bar->flags & UAL_BAR_FLAGS_DEVICE_BE) !=
		    (bar->flags & UAL_BAR_FLAGS_HOST_BE)) {
			/* if original endianess and target one are not
			   compatible, do the swap byte order */
			data[i] = ((data[i] >> 8) & 0x00ff) |
				  ((data[i] << 8) & 0xff00);
		}
	}
}


/**
 * It reads a 16bit value from the given address.
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @return it returns a 16bit value
 */
uint16_t ual_readw(struct ual_bar_tkn *dev, uint32_t addr)
{
	uint16_t data;

	ual_readw_n(dev, addr, &data, 1);

	return data;
}


/**
 * It reads a given number of 8bit values
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @param[out] data preallocated buffer where store data
 * @param[in] n number of values to read
 */
void ual_readb_n(struct ual_bar_tkn *dev, uint32_t addr,
		 uint8_t *data, unsigned int n)
{
	struct ual_bar *bar = (struct ual_bar *)dev;
	int i;

	for (i = 0; i < n; ++i, ++addr) {
		data[i] = *(volatile uint8_t *) (bar->ptr + addr);
	}
}


/**
 * It reads an 8bit value from the given address.
 *
 * @param[in] dev UAL device token returned by ual_open()
 * @param[in] addr offset within the selected BAR
 * @return it returns an 8bit value
 */
uint8_t ual_readb(struct ual_bar_tkn *dev, uint32_t addr)
{
	uint8_t data;

	ual_readb_n(dev, addr, &data, 1);

	return data;
}
