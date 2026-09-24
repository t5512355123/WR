/**
 * @copyright Copyright (c) 2016 CERN
 * @author Federico Vaga <federico.vaga@cern.ch>
 * @license LGPLv3
 *
 * @file ual.h
 */

#ifndef __UAL_H__
#define __UAL_H__

#ifdef __cplusplus
#pragma GCC diagnostic ignored "-Wwrite-strings"
extern "C" {
#endif

#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>


/**
 * @struct ual_bar_tkn
 * Anonymous structure used as token to identify a device address space
 * mapping instance. You can get the token with ual_open(); this token
 * is required by all UAL functions
 */
struct ual_bar_tkn;


/**
 * List of data width
 */
enum ual_data_width {
	UAL_DATA_WIDTH_8 = 1, /**< 1 byte, 8 bit */
	UAL_DATA_WIDTH_16 = 2, /**< 2 byte, 16 bit */
	UAL_DATA_WIDTH_32 = 4, /**< 4 byte, 32 bit */
	UAL_DATA_WIDTH_64 = 8, /**< 8 byte, 64 bit */
};


/**
 * PCI memory map descriptor
 */
struct ual_desc_pci {
	uint64_t devid; /**< PCI device id */
	uint32_t data_width; /**< default register size in bytes */
	uint32_t bar; /**< PCI Base Address Register to access */
	uint64_t size; /**< number of bytes to maps (PAGE_SIZE aligned) */
	uint64_t offset; /**< number of offset bytes from the PCI device
			    base address (PAGE_SIZE aligned) */
	uint64_t flags; /**< set of flags to driver the memory mapping */
};


/**
 * VME memory map descriptor
 */
struct ual_desc_vme {
	uint32_t data_width; /**< default register size in bytes */
	uint32_t am; /**< VME address modifier to use */
	uint64_t size; /**< number of bytes to maps (PAGE_SIZE aligned) */
	uint64_t offset; /**< number of offset bytes from the VME bus
			    base address (PAGE_SIZE aligned) */
	uint64_t flags; /**< set of flags to driver the memory mapping */
};

/**
 * It defines the device endianess:
 *     1 Big Endian, 0 Little Endian
 */
#define UAL_BAR_FLAGS_DEVICE_BE (1 << 0)
/**
 * It defines the host endianess to be used:
 *     1 Big Endian, 0 Little Endian
 * The library will do all the necessary conversions
 */
#define UAL_BAR_FLAGS_HOST_BE (1 << 1)


/**
 * List of available busses. This must be used to open the device and
 * to map its memory.
 *
 * According to the compilation options some of them may not be available.
 * The PCI bus is always available
 */
enum ual_bus_type {
	UAL_BUS_PCI = 0, /**< PCI bus support */
#ifdef CONFIG_VME
	UAL_BUS_VME, /**< VME bus support */
#endif
};


/**
 * UAL error's codes
 */
enum ual_errors {
	UAL_ERR_INVALID_BAR_NUMBER = 1024,
	UAL_ERR_ALREADY_MAPPED,
	UAL_ERR_NOT_OPEN,
	UAL_ERR_NOT_MAPPED,
	UAL_ERR_INVALID_TKN,
	UAL_ERR_INVALID_EVENT_MASK,
	UAL_ERR_INVALID_EVENT_PERIOD,
	UAL_ERR_INVALID_EVENT_CALLBACK,
	UAL_ERR_INVALID_DATA_WIDTH,
	UAL_ERR_INVALID_SIZE,
	UAL_ERR_INVALID_OFFSET,
	/* New errors here */
	__UAL_ERR_MAX,
};

/**
 * @defgroup util Utilities
 * Miscellaneous functions
 * @{
 */
extern char *ual_strerror(int err);
/** @} */

/**
 * @defgroup bar Base Address Register Access
 * Functions to map device address spaces
 * @{
 */
extern struct ual_bar_tkn *ual_open(enum ual_bus_type type, void *desc);
extern void ual_close(struct ual_bar_tkn *dev);
/** @} */


/**
 * @defgroup io Input Output Access
 * Functions to read write from the device memory map
 * @{
 */
extern void ual_readll_n(struct ual_bar_tkn *dev, uint32_t addr,
			uint64_t *data, unsigned int n);
extern void ual_readl_n(struct ual_bar_tkn *dev, uint32_t addr,
			uint32_t *data, unsigned int n);
extern void ual_readw_n(struct ual_bar_tkn *dev, uint32_t addr,
			uint16_t *data, unsigned int n);
extern void ual_readb_n(struct ual_bar_tkn *dev, uint32_t addr,
			uint8_t *data, unsigned int n);
extern uint64_t ual_readll(struct ual_bar_tkn *dev, uint32_t addr);
extern uint32_t ual_readl(struct ual_bar_tkn *dev, uint32_t addr);
extern uint16_t ual_readw(struct ual_bar_tkn *dev, uint32_t addr);
extern uint8_t ual_readb(struct ual_bar_tkn *dev, uint32_t addr);
extern void ual_writell_n(struct ual_bar_tkn *dev, uint32_t addr,
			 uint64_t *data, unsigned int n);
extern void ual_writel_n(struct ual_bar_tkn *dev, uint32_t addr,
			 uint32_t *data, unsigned int n);
extern void ual_writew_n(struct ual_bar_tkn *dev, uint32_t addr,
			 uint16_t *data, unsigned int n);
extern void ual_writeb_n(struct ual_bar_tkn *dev, uint32_t addr,
			 uint8_t *data, unsigned int n);
extern void ual_writell(struct ual_bar_tkn *dev, uint32_t addr, uint64_t data);
extern void ual_writel(struct ual_bar_tkn *dev, uint32_t addr, uint32_t data);
extern void ual_writew(struct ual_bar_tkn *dev, uint32_t addr, uint16_t data);
extern void ual_writeb(struct ual_bar_tkn *dev, uint32_t addr, uint8_t data);
/** @} */


/**
 * @defgroup irq IRQ emulation
 * Functions to emulate the IRQ behaviour
 * @{
 */
extern uint64_t ual_event_wait(struct ual_bar_tkn *tkn, uint64_t addr,
			       uint64_t mask, struct timespec *period,
			       struct timespec *timeout);
/** @} */


#ifdef __cplusplus
}
#endif

#endif
