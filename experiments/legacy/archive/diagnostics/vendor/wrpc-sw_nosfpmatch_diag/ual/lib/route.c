/**
 * @copyright Copyright (c) 2016 CERN
 * @author: Federico Vaga <federico.vaga@cern.ch>
 * @license: LGPLv3
 */

#include <errno.h>
#include <string.h>
#include "ual-int.h"

static char *ual_errors_str[] = {
	"Invalid BAR number",
	"BAR already mapped",
	"BAR not opened",
	"BAR not mapped",
	"Invalid BAR token",
	"Invalid event mask",
	"Invalid event poll period",
	"Invalid event callback",
	"Mapping Data Width must be a power of 2",
	"Mapping size must be page aligned",
	"Mapping offset must be page aligned",
};

static const struct ual_bus *ual_bus[] = {
	[UAL_BUS_PCI] = &ual_pci,
#ifdef CONFIG_VME
	[UAL_BUS_VME] = &ual_vme,
#endif
	/* add new boards here */
};


/**
 * It maps a memory region described by the given descriptor.
 * .
 * @param[in] type bus type to access
 * @param[in] desc memory region description. The descriptor depends on
 the selected bus type
 */
struct ual_bar_tkn *ual_open(enum ual_bus_type type, void *desc)
{
	struct ual_bar *bar;
	int err;

	bar = malloc(sizeof(struct ual_bar));
	if (!bar)
	        goto err_alloc;
	memset(bar, 0, sizeof(struct ual_bar));

	bar->bus = ual_bus[type];
	switch (type) {
	case UAL_BUS_PCI:
		memcpy(&bar->desc.pci, desc, sizeof(struct ual_desc_pci));
		bar->flags = bar->desc.pci.flags;
		break;
#ifdef CONFIG_VME
	case UAL_BUS_VME:
		memcpy(&bar->desc.vme, desc, sizeof(struct ual_desc_vme));
		bar->flags = bar->desc.vme.flags;
		break;
#endif
	}

	err = bar->bus->op->open(bar);
	if (err < 0)
		goto err_open;

	err = bar->bus->op->map(bar);
	if (err < 0)
		goto err_map;

	return (struct ual_bar_tkn *)bar;
 err_map:
	bar->bus->op->close(bar);
 err_open:
	free(bar);
 err_alloc:
	return NULL;
}


/**
 * It closes a given UAL device opened with ual_open(). After the device
 * has been closed it cannot be accesed anymore.
 * @param[in] dev device token to identify a particular opened device
 * @return 0 if no error occurs. Otherwise -1 is returned and errno
 *         is set appropriately
 */
void ual_close(struct ual_bar_tkn *bar_tkn)
{
	struct ual_bar *bar = (struct ual_bar *)bar_tkn;

	bar->bus->op->unmap(bar);
	bar->bus->op->close(bar);
	free(bar);
}


/**
 * Return string describing an error number. If the error number does
 * not belong to the UAL it will uses strerror() to try to get an error
 * message
 * @param[in] err error number, typically from errno
 * @return String corresponding to the given error
 */
char *ual_strerror(int err)
{
	if (err < UAL_ERR_INVALID_BAR_NUMBER || err >= __UAL_ERR_MAX)
		return strerror(err);
	return ual_errors_str[err - UAL_ERR_INVALID_BAR_NUMBER];
}
