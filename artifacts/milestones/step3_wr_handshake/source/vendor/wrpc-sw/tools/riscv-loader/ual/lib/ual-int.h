/**
 * @copyright Copyright (c) 2016 CERN
 * @author Federico Vaga <federico.vaga@cern.ch>
 * @license LGPLv3
 *
 * @file ual-int.h
 */

#ifndef __UAL_INT_H__
#define __UAL_INT_H__

#include "ual.h"


struct ual_bar;


/**
 * Set of operations to make the bus accessible from userspace.
 */
struct ual_bus_operations {
	int (*open)(struct ual_bar *bar); /**< access to any resource */
	int (*close)(struct ual_bar *bar); /**< release resources taken
					      by open() */
	int (*map)(struct ual_bar *bar); /**< map bus address space */
	int (*unmap)(struct ual_bar *bar); /**< release resources taken
					      by map()*/
};


/**
 * BUS descriptor
 */
struct ual_bus {
	char name[16]; /**< Bus name */
	enum ual_bus_type type; /**< bus type unique identifier */
	struct ual_bus_operations *op; /**< specific bus operations */
};


/**
 * Generic BAR descriptor.
 * Any BUS specific details about BAR must be stored in bus_data.
 */
struct ual_bar {
	const struct ual_bus *bus; /**< hardware BUS in use to access the BAR */
	union {
		struct ual_desc_pci pci; /**< PCI address space descriptor */
#ifdef CONFIG_VME
		struct ual_desc_vme vme; /**< VME address space descriptor */
#endif
	} desc; /**< bus access descriptor  */
	void *ptr; /**< mmap(2) pointer that point to the BAR */
	void *bus_data; /**< private date in use by specific BUS */
	uint64_t flags;
	int fd;
};


extern struct ual_bus ual_pci;
#ifdef CONFIG_VME
extern struct ual_bus ual_vme;
#endif

#endif
