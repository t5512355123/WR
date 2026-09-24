/**
 * @copyright Copyright (c) 2016 CERN
 * @author: Federico Vaga <federico.vaga@cern.ch>
 * @license: LGPLv3
 */
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <errno.h>

#include "ual-int.h"


/**
 * Internal PCI descriptor
 */
struct ual_bar_pci {
	char path[1024]; /**< path to PCI device resource */
	int fd; /**< PCI device resource file descriptor*/
};

static int ual_pci_map(struct ual_bar *bar)
{
	struct ual_desc_pci *pci = &bar->desc.pci;
	struct ual_bar_pci *bpci;
	char path[1024];

	bpci = bar->bus_data;
	if (!bpci) {
		errno = UAL_ERR_NOT_OPEN;
		return -1;
	}

	if (bpci->fd >= 0) {
		errno = UAL_ERR_ALREADY_MAPPED;
		return -1;
	}

	snprintf(path, sizeof(path), "/sys/bus/pci/devices/"
		 "/0000:%02"PRIx64":%02"PRIx64".%"PRIx64"/resource%d",
		 (pci->devid >> 16) & 0xFF,
		 (pci->devid >> 8) & 0xFF,
		 (pci->devid) & 0xFF,
		 pci->bar);

        bpci->fd = open(path, O_RDWR | O_SYNC);
	if(bpci->fd < 0)
		return -1;


	if (pci->size & (getpagesize()-1)) {
		errno = UAL_ERR_INVALID_SIZE;
		return -1;
	}

	if (pci->offset & (getpagesize()-1)) {
		errno = UAL_ERR_INVALID_OFFSET;
		return -1;
	}
        bar->ptr = mmap(NULL, pci->size, PROT_READ | PROT_WRITE,
			MAP_SHARED, bpci->fd, pci->offset);

	if ((long)bar->ptr == -1) {
		close(bar->fd);
	        bpci->fd = -1;
		return -1;
	}

	return 0;
}

static int ual_pci_unmap(struct ual_bar *bar)
{
	struct ual_desc_pci *pci = &bar->desc.pci;
	struct ual_bar_pci *bpci = bar->bus_data;

	if (!bpci) {
		errno = UAL_ERR_NOT_OPEN;
		return -1;
	}

	if (bpci->fd < 0) {
		errno = UAL_ERR_NOT_MAPPED;
		return -1;
	}

	munmap(bar->ptr, pci->size);
	close(bpci->fd);
	bpci->fd = -1;

	return 0;
}


static int ual_pci_open(struct ual_bar *bar)
{
	struct ual_bar_pci *bpci;

	bpci = malloc(sizeof(struct ual_bar_pci));
	if (!bpci)
		return -1;
	bpci->fd = -1;
	bpci->path[0] = 0;

	bar->bus_data = bpci;

        return 0;
}

static int ual_pci_close(struct ual_bar *bar)
{
	struct ual_bar_pci *bpci = bar->bus_data;

	if (!bpci) {
		errno = UAL_ERR_NOT_OPEN;
		return -1;
	}

	free(bpci);
	bar->bus_data = NULL;

	return 0;
}



static struct ual_bus_operations ual_pci_op = {
	.open = ual_pci_open,
	.close = ual_pci_close,
	.map = ual_pci_map,
	.unmap = ual_pci_unmap,
};

struct ual_bus ual_pci = {
	.name = "PCI",
	.type = UAL_BUS_PCI,
	.op = &ual_pci_op,
};
