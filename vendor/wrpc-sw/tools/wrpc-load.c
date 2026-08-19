/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2019 CERN (home.cern)
 *
 */

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
#include <getopt.h>
#include <inttypes.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>
#include <stdbool.h>
#include <time.h>
#include <limits.h>

#include "libdevmap.h"
#include "hw/wrc_cpu_csr.h"

static int verbose;
static int flag_check;

static uint32_t wrc_readl(struct mapping_desc *desc, unsigned reg)
{
	uint32_t r = *(volatile uint32_t *)(desc->base + reg );

	if (desc->is_be)
		return ntohl(r);
	else
		return r;
}


static void wrc_writel(struct mapping_desc *desc, unsigned reg, uint32_t value)
{
	if (desc->is_be)
		value = htonl(value);

	*(volatile uint32_t *)(desc->base + reg ) = value;
}

static void wrc_cpu_reset(struct mapping_desc *desc, unsigned int rst)
{
	wrc_writel (desc, 0xc00 + WRC_CPU_CSR_REG_RESET, rst);
}

static void wrc_write_uaddr(struct mapping_desc *desc, unsigned int addr)
{
	wrc_writel(desc, 0xc00 + WRC_CPU_CSR_REG_UADDR, addr >> 2);
}

static int wrc_write_buf(struct mapping_desc *desc,
                         const unsigned char *buf,
                         unsigned len,
                         unsigned addr)
{
	if ((len & 0x03) != 0 || (addr & 0x03) != 0)
		abort();

	while (len > 0) {
		uint32_t v;

		wrc_write_uaddr(desc, addr);

		/* Use BE.  */
		v = (buf[3] << 0)
			| (buf[2] << 8)
			| (buf[1] << 16)
			| (buf[0] << 24);
		wrc_writel(desc, 0xc00 + WRC_CPU_CSR_REG_UDATA, v);

		if (verbose)
			printf ("Write %08x at %08x\n", v, addr);

                if (flag_check) {
                        uint32_t r;
                        wrc_write_uaddr(desc, addr);
                        r = wrc_readl(desc, 0xc00 + WRC_CPU_CSR_REG_UDATA);
                        if (r != v) {
                                printf ("Error at %08x: "
                                        "read %08x instead of %08x\n",
                                        addr, r, v);
                                return -1;
                        }
                }

		len -= 4;
		addr += 4;
		buf += 4;
	}

        return 0;
}

static int wrc_load_firmware(struct mapping_desc *desc, const char *filename)
{
	int fd;
	unsigned char hdr[4];
	unsigned char buf[1024];
	ssize_t res;
	unsigned addr;

	fd = open(filename, O_RDONLY);
	if (fd < 0) {
		fprintf(stderr, "cannot open %s\n", filename);
		return -1;
	}

	res = read(fd, hdr, sizeof(hdr));
	if (res != sizeof(hdr)) {
		fprintf(stderr, "cannot read %s\n", filename);
		goto err_close;
	}

	if (hdr[0] == 0x7f
	    && hdr[1] == 'E' && hdr[2] == 'L' && hdr[3] == 'F') {
		fprintf(stderr, "ELF file %s not yet handled\n", filename);
		goto err_close;
	}

	addr = 0;
	if (wrc_write_buf(desc, hdr, sizeof(hdr), addr) != 0)
                goto err_close;
	addr += sizeof (hdr);

	while (1) {
		res = read(fd, buf, sizeof(buf));
		if (res <= 0)
			break;
		if (wrc_write_buf(desc, buf, res, addr) != 0)
                        goto err_close;
		addr += res;
	}
	printf ("%u KB written\n", addr / 1024);
	close(fd);
	return 0;

err_close:
	close(fd);
	return -1;
}

static int wrc_save_firmware(struct mapping_desc *desc, const char *filename)
{
	int fd;
	unsigned length = 0x20000;
	unsigned char buf[1024];
	ssize_t res;
	unsigned addr;

	fd = open(filename, O_WRONLY);
	if (fd < 0) {
		fprintf(stderr, "cannot open %s\n", filename);
		return -1;
	}

	for (addr = 0; addr < length;) {
		unsigned l = length - addr;
		unsigned off;
		if (l > sizeof (buf))
			l = sizeof (buf);

		for (off = 0; off < l; off += 4) {
			unsigned int v;
			wrc_write_uaddr(desc, addr);
			v = wrc_readl(desc, 0xc00 + WRC_CPU_CSR_REG_UDATA);
			/* Use BE */
			buf[off + 0] = v >> 24;
			buf[off + 1] = v >> 16;
			buf[off + 2] = v >> 8;
			buf[off + 3] = v >> 0;

			addr += 4;
		}
		res = write(fd, buf, l);
		if (res != l) {
			fprintf(stderr, "write failure\n");
			close(fd);
			return -1;
		}
	}

	printf ("%u KB written to %s\n", length / 1024, filename);
	close(fd);
	return 0;
}

static void wrc_dump(struct mapping_desc *desc, unsigned addr, unsigned len)
{
	unsigned off;

	off = 0;
	for (off = 0; off < len; off += 4) {
		uint32_t v;

		if ((off & 0x0f) == 0)
			printf ("%08x:", addr + off);

		wrc_write_uaddr(desc, addr + off);

		v = wrc_readl(desc, 0xc00 + WRC_CPU_CSR_REG_UDATA);
		printf (" %08x", v);
		if ((off & 0x0f) == 0xc)
			printf ("\n");
	}
	if ((off & 0x0f) != 0xc)
		printf ("\n");
}

static void wrpc_load_help(char *prog)
{
	const char *mapping_help_str;

	mapping_help_str = dev_mapping_help();
	fprintf(stderr, "%s [-v] [-h] [-s] filename\n", prog);
	fprintf(stderr, "%s\n", mapping_help_str);
	fprintf(stderr, "(offset should be 0, address is the wrpc registers base)\n");
	fprintf(stderr, "Only for risc-v\n");
	fprintf(stderr, "Use -s to save memory to a file\n");
}

int main(int argc, char *argv[])
{
	int c;
        int status;
	const char *filename;
	struct mapping_args *map_args;
	struct mapping_desc *mdesc = NULL;
	enum { CMD_LOAD, CMD_DUMP, CMD_SAVE } cmd;

	map_args = dev_parse_mapping_args(&argc, argv);
	if (!map_args) {
		wrpc_load_help(argv[0]);
		return 1;
	}

        status = 0;

	cmd = CMD_LOAD;
	while ((c = getopt(argc, argv, "hvdsc")) != -1) {
		switch (c) {
		case 'h':
			wrpc_load_help(argv[0]);
			exit(EXIT_SUCCESS);
			break;
		case 'd':
			cmd = CMD_DUMP;
			break;
		case 's':
			cmd = CMD_SAVE;
			break;
		case 'v':
			verbose++;
			break;
                case 'c':
                        flag_check++;
                        break;
		case '?':
                        printf("%s: unknown option, try -h\n", argv[0]);
                        exit(1);
		}
	}

	if (((cmd == CMD_LOAD || cmd == CMD_SAVE) && (optind != argc - 1))
	    || (cmd == CMD_DUMP && optind != argc)) {
		wrpc_load_help(argv[0]);
		return 2;
	}
	filename = argv[optind];

	mdesc = dev_map(map_args, getpagesize());
	if (!mdesc) {
		fprintf(stderr, "%s: failed to map: %s\n", argv[0],
			strerror(errno));
		return 1;
	}

	/* Reset */
	wrc_cpu_reset(mdesc, 1 << 0);

	switch (cmd) {
	case CMD_LOAD:
		/* Load */
		if (wrc_load_firmware (mdesc, filename) < 0)
                        status = 1;
		break;
	case CMD_SAVE:
		/* Save */
		wrc_save_firmware (mdesc, filename);
		break;
	case CMD_DUMP:
		/* TODO: specify offset and length */
		wrc_dump(mdesc, 0, 0x200);
		break;
	}

	/* Start */
	wrc_cpu_reset(mdesc, 0);

	return status;
}
