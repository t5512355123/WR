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
#include <string.h>
#include <libvmebus.h>

#include "ual-int.h"

struct ual_bar_vme {
	struct vme_mapping *map;
};

static int ual_vme_map(struct ual_bar *bar)
{
	struct ual_desc_vme *vme = &bar->desc.vme;
	struct ual_bar_vme *bvme;

	bvme = bar->bus_data;
	if (!bvme) {
		errno = UAL_ERR_NOT_OPEN;
		return -1;
	}
	if (bvme->map) {
		errno = UAL_ERR_ALREADY_MAPPED;
		return -1;
	}

	if (vme->size & (getpagesize()-1)) {
		errno = UAL_ERR_INVALID_SIZE;
		return -1;
	}

	if (vme->offset & (getpagesize()-1)) {
		errno = UAL_ERR_INVALID_OFFSET;
		return -1;
	}

	bvme->map = malloc(sizeof(struct vme_mapping));
	if (!bvme)
		goto err_alloc;


	/* Prepare mmap description */
	memset(bvme->map, 0, sizeof(struct vme_mapping));
	bvme->map->am = vme->am;
	bvme->map->data_width = vme->data_width * 8;
	bvme->map->sizel = vme->size;
	bvme->map->vme_addrl = vme->offset;

	/* Do mmap */
	bar->ptr = vme_map(bvme->map, 1);
	if (!bar->ptr)
		goto err_map;

	return 0;
err_map:
	free(bvme->map);
err_alloc:
	bvme->map = NULL;
	return -1;

}

static int ual_vme_unmap(struct ual_bar *bar)
{
	struct ual_bar_vme *bvme = bar->bus_data;

	if (!bvme) {
		errno = UAL_ERR_NOT_OPEN;
		return -1;
	}

	if (!bvme->map) {
		errno = UAL_ERR_NOT_MAPPED;
		return -1;
	}

        vme_unmap(bvme->map, 1);

	return 0;
}


int ual_vme_open(struct ual_bar *bar)
{
	struct ual_bar_vme *bvme;

	bvme = malloc(sizeof(struct ual_bar_vme));
	if (!bvme)
		return -1;

	bvme->map = NULL;
	bar->bus_data = bvme;

        return 0;
}

int ual_vme_close(struct ual_bar *bar)
{
	struct ual_bar_vme *bvme = bar->bus_data;

	if (!bvme) {
		errno = UAL_ERR_NOT_OPEN;
		return -1;
	}

	free(bvme);
	bar->bus_data = NULL;

	return 0;
}



static struct ual_bus_operations ual_vme_op = {
	.open = ual_vme_open,
	.close = ual_vme_close,
	.map = ual_vme_map,
	.unmap = ual_vme_unmap,
};

struct ual_bus ual_vme = {
	.name = "VME",
	.type = UAL_BUS_VME,
	.op = &ual_vme_op,
};
