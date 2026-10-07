/*
 * Copyright (c) 2016 CERN
 * Author: Federico Vaga <federico.vaga@cern.ch>
 * License: LGPLv3
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <inttypes.h>
#include <getopt.h>
#include <ual.h>

void help(char *name)
{
	fprintf(stderr,	"Use: \"%s [OPTIONS]\"\n", name);

	fprintf(stderr,
		"\nIt allows to access registers on PCI/VME devices.\n");
	fprintf(stderr,
		"The tool allows to read or write a register or to wait for a given set of bit to change.\n");
	fprintf(stderr,
		"The tools applies these operations with the following priority:\n");

	fprintf(stderr, "\t1- wait [optional]\n");
	fprintf(stderr, "\t2- write [optional]\n");
	fprintf(stderr, "\t3- read\n");

	fprintf(stderr, "\nGlobal Options:\n");
	fprintf(stderr, "\t--data-width <number>: access data width in bytes [1, 2, 4, 8]\n");
	fprintf(stderr, "\t--offset : Offset within the mapped memory\n");
	fprintf(stderr, "\t--count, -c <number> : Number of consecutive registers to read\n");
	fprintf(stderr, "\t--address, -a 0x<number> : address to access\n");

	fprintf(stderr, "\nPCI Options:\n");
	fprintf(stderr, "\t--pci: set bus type to PCI\n");
	fprintf(stderr, "\t--pci-bar <number> : BAR index\n");
	fprintf(stderr, "\t--pci-device <bus>:<dev>.<fn>: (<hex>:<hex>.<hex>) PCI device ID\n");
#ifdef CONFIG_VME
	fprintf(stderr, "\nVME Options:\n");
	fprintf(stderr, "\t--vme: set bus type to VME\n");
	fprintf(stderr, "\t--vme-am 0x<hex-number> : VME address-modifier\n");
#endif
	fprintf(stderr, "\nEndianess Options:\n");
	fprintf(stderr, "\t--device-be: the device is Big Endian\n");
	fprintf(stderr, "\t--device-le: the device is Little Endian (default)\n");
	fprintf(stderr, "\t--target-be: the target endianess is Big Endian\n");
	fprintf(stderr, "\t--target-le: the target endianess is Little Endian (default)\n");

	fprintf(stderr, "\nWait Event Options:\n");
	fprintf(stderr, "\t--wait: it enable the wait mode\n");
	fprintf(stderr, "\t--wait-mask 0x<number>: mask to to select which bits do you want to poll\n");
	fprintf(stderr, "\t--wait-period <number>: period between poll in micro-seconds (default 100ms)\n");
	fprintf(stderr, "\t--wait-timeout <number>: timeout in micro-seconds (default 10s)\n");

	fprintf(stderr, "\nWrite Options:\n");
	fprintf(stderr, "\t--value, -v 0x<number> : value to write\n");
	exit(1);
}

enum ualmem_option_index {
	UO_NONE = 0,
	UO_WAIT_MASK,
	UO_WAIT_PERIOD,
	UO_WAIT_TIMEOUT,
	UO_PCI_DEVID,
	UO_PCI_BAR,
	UO_VME_AM,
};

static int wait = 0;
/* Default value: period 100ms timeout 10s */
static unsigned int wait_mask = ~0, wait_period = 100000, wait_timeout = 10000000;

static int bus_type = -1, device_endianess = 0, target_endianess = 0;
static struct option long_options[] = {
	/* Generic options */
	{"data-width", required_argument, 0, 'w'},
	{"offset", required_argument, 0, 'o'},
	{"count", required_argument, 0, 'c'},
	{"address", required_argument, 0, 'a'},
	/* PCI options */
	{"pci", no_argument, &bus_type, UAL_BUS_PCI},
	{"pci-bar", required_argument, 0, UO_PCI_BAR},
	{"pci-device", required_argument, 0, UO_PCI_DEVID},
#ifdef CONFIG_VME
	/* VME options */
	{"vme", no_argument, &bus_type, UAL_BUS_VME},
	{"vme-am", required_argument, 0, UO_VME_AM},
#endif
	/* Endianess options */
	{"device-be", no_argument, &device_endianess, 1},
	{"device-le", no_argument, &device_endianess, 0},
	{"target-be", no_argument, &target_endianess, 1},
	{"target-le", no_argument, &target_endianess, 0},
	/* Wait options */
	{"wait", no_argument, &wait, 1},
	{"wait-mask", required_argument, 0, UO_WAIT_MASK},
	{"wait-period", required_argument, 0, UO_WAIT_PERIOD},
	{"wait-timeout", required_argument, 0, UO_WAIT_TIMEOUT},
	/* Write options */
	{"value", required_argument, 0, 'v'},
	{0, 0, 0, 0}
};

int main(int argc, char **argv)
{
	struct ual_bar_tkn *ubar;
	uint64_t address = 0, flags = 0, offset = 0, dw = UAL_DATA_WIDTH_32;
	uint64_t *val, size, ret;
	unsigned int num = 1, num_val = 0, off = 0;
	int c, i, option_index = 0, val_idx = 0;
	struct ual_desc_pci pci;
	struct ual_desc_vme vme;

	memset(&pci, 0, sizeof(struct ual_desc_pci));
	memset(&vme, 0, sizeof(struct ual_desc_vme));

	if (argc == 1)
		help(argv[0]);

	while ((c = getopt_long(argc, argv, "C:a:v:c:w:s:o:", long_options,
				&option_index)) != -1)
	{
		switch (c) {
		case 'v':
			num_val++;
			break;
		default:
			break;
		}
	}

	if (num_val) {
		val = calloc(num_val, sizeof(uint64_t));
		if (!val) {
			fprintf(stderr, "Cannot allocate buffer\n");
			exit(1);
		}
	}

	/* Parse options */
	option_index = 0;
	optind = 1;
	while ((c = getopt_long(argc, argv, "C:a:v:c:w:s:o:", long_options,
				&option_index)) != -1)
	{

		/*
		 * when checking multiple format (%d and 0x%x) always
		 * give precendece to 0x%x. The otherway around will
		 * always match %d with the first zero in 0x1234 when
		 * the provided number is in hex format
		 */
		switch(c) {
		case UO_NONE:
			/* all handled by getopt_long*/
			break;
		case UO_WAIT_MASK:
			i = sscanf(optarg, "0x%"SCNx32, &wait_mask);
			if (i == 1)
				break;
			fprintf(stderr, "Mask must be writte in hex format\n");
			break;
		case UO_WAIT_PERIOD:
			i = sscanf(optarg, "%u", &wait_period);
			if (i == 1)
				break;
			fprintf(stderr, "Mask must be writte in dec format\n");
			break;
		case UO_WAIT_TIMEOUT:
			i = sscanf(optarg, "%u", &wait_timeout);
			if (i == 1)
				break;
			fprintf(stderr, "Mask must be writte in dec format\n");
			break;
		case UO_PCI_DEVID: {
			int b, d, f;
			i = sscanf(optarg, "%x:%x.%x", &b, &d, &f);
			if (i == 3) {
				b &= 0xFF;
				d &= 0xFF;
				f &= 0xFF;
				pci.devid = (b << 16) | (d << 8) | f;
				break;
			}
			fprintf(stderr, "Invalid PCI device id '%s'. It must be '%%x:%%x.%%x'\n",
				optarg);
			break;
		}
		case UO_PCI_BAR:
			i = sscanf(optarg, "%u", &pci.bar);
			if (i == 1)
				break;
			fprintf(stderr, "PCI bar must be a decimal integer\n");
			break;
#ifdef CONFIG_VME
		case UO_VME_AM:
			i = sscanf(optarg, "0x%x", &vme.am);
			if (i == 1)
				break;
			fprintf(stderr, "VME address-modifier must be an hexadicimal number\n");
			break;
#endif
		case 'a':
			i = sscanf(optarg, "0x%"SCNx64, &address);
			if (i == 1)
				break;
			fprintf(stderr, "Invalid base address offset: it must be a hex value\n");
			exit(1);
			break;
		case 'v':
			i = sscanf(optarg, "0x%"SCNx64, &val[val_idx]);
			if (i == 1) {
				++val_idx;
				break;
			}
			i = sscanf(optarg, "%"SCNd64, &val[val_idx]);
			if (i == 1) {
				++val_idx;
				break;
			}
			fprintf(stderr, "Invalid register value '%s'\n", optarg);
			exit(1);
			break;
		case 'c':
			i = sscanf(optarg, "%u", &num);
			if (i == 1)
				break;
			fprintf(stderr, "Invalid count value '%s'\n", optarg);
			exit(1);
			break;
		case 'w':
			i = sscanf(optarg, "%"SCNx64, &dw);
			if (i == 1 &&
			    (dw == 1 || dw == 2 || dw == 4 || dw == 8))
				break;
			fprintf(stderr, "Invalid data width '%s'\n", optarg);
			exit(1);
			break;
		case 's':
			i = sscanf(optarg, "0x%"SCNx64, &size);
			if (i == 1)
				break;
			i = sscanf(optarg, "%"SCNd64, &size);
			if (i == 1)
				break;
			fprintf(stderr, "Invalid size format '%s'\n", optarg);
			exit(1);
		case 'o':
			i = sscanf(optarg, "0x%"SCNx64, &offset);
			if (i == 1)
				break;
			i = sscanf(optarg, "%"SCNd64, &offset);
			if (i == 1)
				break;
			fprintf(stderr, "Invalid offset format '%s'\n", optarg);
			exit(1);
		default:
			help(argv[0]);
		}
	}

	errno = 0; /* reset errno to better handle the exit() */
	if (device_endianess) {
	        flags |= UAL_BAR_FLAGS_DEVICE_BE;
	}
	if (target_endianess) {
	        flags |= UAL_BAR_FLAGS_HOST_BE;
	}

	/* Compute mapping size */
	size = getpagesize() * ((int)(address / getpagesize()) + 1);

	/* Open the device with UAL library */
	switch (bus_type) {
	case UAL_BUS_PCI:
		pci.data_width = dw;
		pci.size = size;
		pci.offset = offset;
		pci.flags = flags;
		ubar = ual_open(bus_type, &pci);
		break;
#ifdef CONFIG_VME
	case UAL_BUS_VME:
		vme.data_width = dw;
		vme.size = size;
		vme.offset = offset;
		vme.flags = flags;
		ubar = ual_open(bus_type, &vme);
		break;
#endif
	default:
		fprintf(stderr, "The BUS type options is mandatory\n");
		exit(1);
	}

	if (!ubar) {
		fprintf(stderr, "Cannot open device: %s\n", ual_strerror(errno));
		exit(1);
	}

	if (wait) {
		struct timespec p = {wait_period / 1000000, };
		struct timespec t = {wait_timeout / 1000000, };

		p.tv_nsec = (wait_period - (p.tv_sec * 1000000)) * 1000;
		t.tv_nsec = (wait_timeout - (t.tv_sec * 1000000)) * 1000;

		printf("Wait event\n");
		printf("Poll period: %lld[s] %ld[ns]\n",
		       (long long)p.tv_sec, p.tv_nsec);
		printf("Timeout    : %lld[s] %ld[ns]\n",
		       (long long)t.tv_sec, t.tv_nsec);
		ret = ual_event_wait(ubar, address, wait_mask, &p, &t);
		if (!ret) {
			fprintf(stderr, "Cannot open device: %s\n",
				ual_strerror(errno));
			goto out;
		}
		printf("[0x%016"PRIx64"] = 0x%016"PRIx64" (masked)\n",
			       address, ret);
		printf("Time left  : %lld[s] %ld[ns]\n",
		       (long long)t.tv_sec, t.tv_nsec);
	}

	/* Write when asked */
	if (num_val) {
		switch (dw) {
		case UAL_DATA_WIDTH_8: {
			uint8_t tmp[num_val];

			for (i = 0; i < num_val; ++i)
				tmp[i] = (uint8_t)val[i];
			ual_writeb_n(ubar, address, tmp, num_val);

			for (i = 0, off = 0; i < num_val; ++i, off += dw)
				printf("[0x%016"PRIx64"] W 0x%02"PRIx8"\n",
				       address + off, tmp[i]);
			break;
		}
		case UAL_DATA_WIDTH_16: {
			uint16_t tmp[num_val];

			for (i = 0; i < num_val; ++i)
				tmp[i] = (uint16_t)val[i];
			ual_writew_n(ubar, address, tmp, num_val);

			for (i = 0, off = 0; i < num_val; ++i, off += dw)
				printf("[0x%016"PRIx64"] W 0x%04"PRIx16"\n",
				       address + off, tmp[i]);
			break;
		}
		case UAL_DATA_WIDTH_32: {
			uint32_t tmp[num_val];

			for (i = 0; i < num_val; ++i)
				tmp[i] = (uint32_t)val[i];
			ual_writel_n(ubar, address, tmp, num_val);

			for (i = 0, off = 0; i < num_val; ++i, off += dw)
				printf("[0x%016"PRIx64"] W 0x%08"PRIx32"\n",
				       address + off, tmp[i]);
			break;
		}
		case UAL_DATA_WIDTH_64: {
			uint64_t tmp[num_val];

			for (i = 0; i < num_val; ++i)
				tmp[i] = (uint64_t)val[i];
			ual_writell_n(ubar, address, tmp, num_val);

			for (i = 0, off = 0; i < num_val; ++i, off += dw)
				printf("[0x%016"PRIx64"] W 0x%016"PRIx64"\n",
				       address + off, tmp[i]);
			break;
		}
		}
	}

	/* Read value */
	switch (dw) {
	case UAL_DATA_WIDTH_8: {
		uint8_t tmp[num];

		ual_readb_n(ubar, address, tmp, num);
		for (i = 0, off = 0; i < num; ++i, off += dw)
			printf("[0x%016"PRIx64"] R 0x%02"PRIx8"\n",
			       address + off, tmp[i]);
		break;
	}
	case UAL_DATA_WIDTH_16: {
		uint16_t tmp[num];

		ual_readw_n(ubar, address, tmp, num);
		for (i = 0, off = 0; i < num; ++i, off += dw)
			printf("[0x%016"PRIx64"] R 0x%04"PRIx16"\n",
			       address + off, tmp[i]);
		break;
	}
	case UAL_DATA_WIDTH_32: {
		uint32_t tmp[num];

		ual_readl_n(ubar, address, tmp, num);
		for (i = 0, off = 0; i < num; ++i, off += dw)
			printf("[0x%016"PRIx64"] R 0x%08"PRIx32"\n",
			       address + off, tmp[i]);
		break;
	}
	case UAL_DATA_WIDTH_64: {
		uint64_t tmp[num];

		ual_readll_n(ubar, address, tmp, num);
		for (i = 0, off = 0; i < num; ++i, off += dw)
			printf("[0x%016"PRIx64"] R 0x%016"PRIx64"\n",
			       address + off, tmp[i]);
		break;
	}
	}

out:
	ual_close(ubar);

	exit(errno);
}
