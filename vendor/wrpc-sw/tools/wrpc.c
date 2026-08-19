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
#include <sys/time.h>
#include <stdbool.h>
#include <time.h>
#include <limits.h>
#include <termios.h>
#include <signal.h>
#include <stddef.h>
#include <elf.h>

#ifdef SUPPORT_CERN_VMEBRIDGE
#include <libvmebus.h>
#endif

#define SUPPORT_ERTM

#ifdef SUPPORT_ERTM
#include "libertm.h"
#endif
#include "spll_debug.h"

#include "hw/wrc_cpu_csr.h"
#include "hw/wrc_syscon_regs.h"
#include "hw/wb_uart.h"
#include "hw/softpll_regs.h"
#include "hw/wrc_diags_regs.h"

/* From include/boards.h */
#define OFFSET_SOFTPLL		0x200
#define OFFSET_SYSCON		0x400
#define OFFSET_UART		0x500
#define OFFSET_WDIAGS		0xa00
#define OFFSET_CPU_CSR		0xd00

#define VUART_EOL 13
#define VUART_CMD_USLEEP 1000000
#define VUART_CMD_PROMPT "wrc#"

static const char *progname;

struct tool_base {
	const char *name;
        const char *short_help;
	int (*run)(int argc, char *argv[]);
	void (*help)(void);
};

struct board {
	const char *name;
	int (*init)(struct board *board, int *argc, char *argv[]);
	int (*fini)(struct board *board);
	void (*help)(void);
	uint32_t (*readl)(struct board *board, unsigned off);
	void (*writel)(struct board *board, unsigned off, uint32_t v);
};

static struct board *board;

static const struct tool_base *tools[];

static int verbose;
static int flag_check;

static void remove_arg1(int *argc, char *argv[])
{
	for (unsigned i = 2; i < *argc; i++)
		argv[i - 1] = argv[i];
	(*argc)--;
}

/* Any board which can be mapped into memory.  */
struct board_mem {
	struct board parent;
	volatile void *base;
	int is_be;
	void *map_addr;
	unsigned map_length;
};

struct board_pci {
	struct board_mem parent;
	const char *resource_file;
	uint64_t offset;
};

struct board_ertm14 {
	struct board parent;
	const char* uart_dev;
	struct ertm_status *handle;
};

struct pci_slot {
	unsigned domain;
	unsigned bus;
	unsigned slot;
	unsigned func;

	unsigned bar;
};

static int parse_pci_slot(struct pci_slot *res, const char *s)
{
	char *e;

	res->domain = strtoul (s, &e, 16);
	if (*e != ':') {
		fprintf (stderr, "missing pci device id in '%s'\n", s);
		return -1;
	}
	res->bus = strtoul (e + 1, &e, 16);
	if (*e == ':')
		res->slot = strtoul (e + 1, &e, 16);
	else {
		res->slot = res->bus;
		res->bus = res->domain;
		res->domain = 0;
	}
	if (*e == '.')
		res->func = strtoul (e + 1, &e, 16);
	else
		res->func = 0;
	if (*e == '@')
		res->bar = strtoul (e + 1, &e, 10);
	else
		res->bar = 0;
	if (*e != 0) {
		fprintf (stderr, "incorrect pci slot format in '%s'\n", s);
		return -1;
	}
	return 0;
}

static int board_pci_common_open(struct board_pci *board)
{
	int fd;
	unsigned pg = getpagesize();
	unsigned map_len = pg;
	unsigned pa_offset;

	fd = open(board->resource_file, O_RDWR | O_SYNC);
	if (fd < 0) {
		fprintf(stderr, "cannot open resource file '%s': %s\n",
			board->resource_file, strerror(errno));
		return -1;
	}

	/* offset is page aligned */
	pa_offset = board->offset & ~(getpagesize() - 1);
	board->parent.map_addr = mmap(NULL, map_len,
			   PROT_READ | PROT_WRITE,
			   MAP_SHARED, fd, pa_offset);
	if (board->parent.map_addr == MAP_FAILED) {
		fprintf(stderr, "cannot map resource file '%s': %s\n",
			board->resource_file, strerror(errno));
		close(fd);
		return -1;
	}
	close(fd);

	board->parent.map_length = pg;
	board->parent.base =
		board->parent.map_addr + (board->offset - pa_offset);

	board->parent.is_be = 0; /* default set to little endian */

	return 0;
}

/* Parse PCI board identifier (either resource file or slot).  */

static int parse_pci_board(struct board_pci *board, int *argc, char *argv[])
{
	/* Args: -f file, -o offset */
	if (*argc > 2 && !strcmp (argv[1], "-f")) {
		remove_arg1(argc, argv);
		board->resource_file = argv[1];
		remove_arg1(argc, argv);
	}
	else if (*argc > 2 && !strcmp(argv[1], "-s")) {
		static char pci_file[64];
		struct pci_slot slot;
		remove_arg1(argc, argv);
		if (parse_pci_slot(&slot, argv[1]) < 0)
			return -1;
		remove_arg1(argc, argv);
		snprintf (pci_file, sizeof(pci_file),
			  "/sys/bus/pci/devices/%04x:%02x:%02x.%x/resource%u",
			  slot.domain, slot.bus, slot.slot, slot.func,
			  slot.bar);
		board->resource_file = pci_file;
	}
	else {
		fprintf(stderr, "missing '-f resource-file' or '-s [dom:]bus:slot[.fn][@bar]' for pci\n");
		return -1;
	}

        return 0;
}

static int board_pci_init(struct board *board_base,
			  int *argc, char *argv[])
{
	struct board_pci *board = (struct board_pci *)board_base;

        if (parse_pci_board(board, argc, argv) < 0)
                return -1;

	if (*argc > 2 && !strcmp (argv[1], "-o")) {
		char *e;
		remove_arg1(argc, argv);
		board->offset = strtoul(argv[1], &e, 0);
		if (*e != 0) {
			fprintf (stderr, "bad offset '%s'\n", argv[1]);
			return -1;
		}
		remove_arg1(argc, argv);
	}

	if (board_pci_common_open(board) < 0)
		return -1;
	return 0;
}


static int board_pci_fini(struct board *base_board)
{
	struct board_pci *board = (struct board_pci *)base_board;
	munmap(board->parent.map_addr, board->parent.map_length);

	return 0;
}

static void board_pci_help(void)
{
        printf("Generic PCI board\n");
        printf(" -f resource-file\n");
        printf(" -s [domain:]bus:slot[.func][@bar]\n");
        printf(" -o offset\n");
        printf("One of -f or -s is required to identify the board\n");
}

#ifdef SUPPORT_ERTM
static void board_ertm14_help(void)
{
        printf("eRTM14/15 board\n");
        printf(" -e USB/UART device \n");
        printf("Note only the SoftPLL recorder tool is available. Others will not work.\n");
}

static int board_ertm14_fini(struct board *base_board)
{
	struct board_ertm14 *board = (struct board_ertm14 *)base_board;

	if(board->handle)
		ertm_exit(board->handle);

	return 0;
}


static int board_ertm14_init(struct board *board_base,
			  int *argc, char *argv[])
{
	struct board_ertm14 *board = (struct board_ertm14 *)board_base;
	printf("bi");

	/* Args: -f file, -o offset */
	if (*argc > 2 && !strcmp (argv[1], "-e")) {
		remove_arg1(argc, argv);
		board->uart_dev = argv[1];
		remove_arg1(argc, argv);
	}

	if( !board->uart_dev )
	{
		fprintf(stderr, "ertm14: USB/UART device expected (-e option, check help).\n");
		return -1;
	}

	struct ertm_status *handle = ertm_init(board->uart_dev);

	if (handle == NULL)
	{
		fprintf(stderr, "ertm14: could not open %s\n", board->uart_dev);
		return -1;
	}

	board->handle = handle;

	return 0;
}

static struct board_ertm14 board_ertm14 =
{
		{
			"ertm14",
			board_ertm14_init,
			board_ertm14_fini,
			board_ertm14_help,
			NULL,
			NULL
		},
		NULL,
		NULL
};
#endif /* SUPPORT_ERTM */

static uint32_t mem_readl(struct board *base_board, unsigned reg)
{
	struct board_mem *board = (struct board_mem *)base_board;

	uint32_t r = *(volatile uint32_t *)(board->base + reg);

	if (board->is_be)
		return ntohl(r);
	else
		return r;
}

static void mem_writel(struct board *base_board, unsigned reg, uint32_t value)
{
	struct board_mem *board = (struct board_mem *)base_board;

	if (board->is_be)
		value = htonl(value);

	*(volatile uint32_t *)(board->base + reg ) = value;
}

static struct board_pci board_pci =
{
	{
		{
			"pci",
			board_pci_init,
			board_pci_fini,
			board_pci_help,
			mem_readl,
			mem_writel
		},
		NULL,
		0,
		NULL,
		0
	},
	NULL,
	0
};


static int board_spec_init(struct board *board_base,
			  int *argc, char *argv[])
{
	struct board_pci *board = (struct board_pci *)board_base;

        if (parse_pci_board(board, argc, argv) < 0)
                return -1;

	if (board_pci_common_open(board) < 0)
		return -1;
	return 0;
}

static void board_spec_help(void)
{
        printf("SPEC board (using the convention)\n");
        printf(" -f resource-file \n");
        printf(" -s [domain:]bus:slot[.func]\n");
        printf("One of -f or -s is required to identify the board\n");
        printf("(wrpc is at offset 0x1000)\n");
}

static struct board_pci board_spec =
{
	{
		{
			"spec",
			board_spec_init,
			board_pci_fini,
			board_spec_help,
			mem_readl,
			mem_writel
		},
		NULL,
		0,
		NULL,
		0
	},
	NULL,
	0x1000
};

#ifdef SUPPORT_CERN_VMEBRIDGE
struct board_cernvme {
        struct board_mem parent;
	uint32_t data_width; /**< default register size in bytes */
	uint32_t am; /**< VME address modifier to use */
	uint64_t addr; /**< physical base address */
        uint32_t offset;
        struct vme_mapping map;
};

static int cernvme_map(struct board_cernvme *board,
                       unsigned am, unsigned dw,
                       unsigned vme_addr, unsigned offset)
{
        unsigned pg = getpagesize();

        memset(&board->map, 0, sizeof(struct vme_mapping));
        board->map.am = am;
        board->map.data_width = dw;
        board->map.sizel = pg;
        board->map.vme_addrl = vme_addr | (offset & ~(pg - 1));

        board->parent.map_addr = vme_map(&board->map, 1);
        if (!board->parent.map_addr) {
                fprintf(stderr, "cannot map vme: %s\n", strerror(errno));
                return -1;
        }
        board->parent.map_length = pg;
	board->parent.base = board->parent.map_addr + (offset & (pg - 1));

        board->parent.is_be = 1;

        return 0;
}

static int board_cernvme_init(struct board *board_base,
                              int *argc, char *argv[])
{
	struct board_cernvme *board = (struct board_cernvme *)board_base;

        unsigned vme_addr = ~0;
        unsigned data_width = 32;
        unsigned am = 0x39;
        unsigned offset = 0;

        while (*argc > 2) {
                if (argv[1][0] != '-')
                        break;

                if (!strcmp(argv[1], "-a") || !strcmp(argv[1], "--address")) {
                        char *e;
                        remove_arg1(argc, argv);
                        vme_addr = strtoul(argv[1], &e, 0);
                        if (*e != 0) {
                                fprintf(stderr, "invalid address '%s'\n", argv[1]);
                                return -1;
                        }
                        remove_arg1(argc, argv);
                }
                else if (!strcmp(argv[1], "-s") || !strcmp(argv[1], "--slot")) {
                        char *e;
                        unsigned slot;

                        remove_arg1(argc, argv);
                        slot = strtoul(argv[1], &e, 0);
                        if (*e != 0) {
                                fprintf(stderr, "invalid slot '%s'\n", argv[1]);
                                return -1;
                        }
                        vme_addr = slot << 19;
                        remove_arg1(argc, argv);
                }
                else if (!strcmp(argv[1], "-w")
                         || !strcmp(argv[1], "--data-width")) {
                        char *e;

                        remove_arg1(argc, argv);
                        data_width = strtoul(argv[1], &e, 0);
                        if (*e != 0) {
                                fprintf(stderr, "invalid data-width '%s'\n", argv[1]);
                                return -1;
                        }
                        if (!(data_width == 8
                              || data_width == 16
                              || data_width == 32)) {
                                fprintf(stderr, "invalid data-width %u\n",
                                        data_width);
                                return -1;
                        }
                        remove_arg1(argc, argv);
                }
                else if (!strcmp(argv[1], "-m")
                         || !strcmp(argv[1], "--am")) {
                        char *e;

                        remove_arg1(argc, argv);
                        am = strtoul(argv[1], &e, 0);
                        if (*e != 0) {
                                fprintf(stderr, "invalid address-modifier '%s'\n", argv[1]);
                                return -1;
                        }
                        remove_arg1(argc, argv);
                }
                else if (!strcmp (argv[1], "-o")
                         || !strcmp(argv[1], "--offset")) {
                        char *e;
                        remove_arg1(argc, argv);
                        offset = strtoul(argv[1], &e, 0);
                        if (*e != 0) {
                                fprintf (stderr, "bad offset '%s'\n", argv[1]);
                                return -1;
                        }
                        remove_arg1(argc, argv);
                }
                else
                        break;

        }

        if (vme_addr == ~0) {
                fprintf (stderr,
                         "vme address (-a) or vme slot (-s) required\n");
                return -1;
        }

        return cernvme_map (board, am, data_width, vme_addr, offset);
}

static int board_cernvme_fini(struct board *base_board)
{
	struct board_cernvme *board = (struct board_cernvme *)base_board;
        vme_unmap(&board->map, 1);

	return 0;
}

static void board_cernvme_help(void)
{
        printf("VME board (using CERN-vme bridge)\n");
        printf(" -a, --address ADDR   board address\n");
        printf(" -s, --slot ADDR      board slot (512KB steps)\n");
        printf(" -w, --data-width WD  data width\n");
        printf(" -m, --am AM          address modified\n");
        printf(" -o, --offset OFF     offset\n");
        printf("One of -a or -s is required\n");
}

static struct board_cernvme board_cernvme =
{
	{
		{
			"vme",
			board_cernvme_init,
			board_cernvme_fini,
			board_cernvme_help,
			mem_readl,
			mem_writel
		},
		NULL,
		0,
		NULL,
		0
	},
};

static uint32_t wr2rf_readl(struct board *base_board, unsigned reg)
{
	struct board_mem *board = (struct board_mem *)base_board;
        volatile uint16_t *addr = (volatile uint16_t *)(board->base + reg);
        uint32_t l, h, res;

        /* A 16b VME bus with special circuitery to get an atomic 32b value */
	l = addr[0];
	h = addr[1];
	res = (l << 16) | h;
	return ntohl(res);
}

static void wr2rf_writel(struct board *base_board, unsigned reg, uint32_t val)
{
	struct board_mem *board = (struct board_mem *)base_board;
        volatile uint16_t *addr = (volatile uint16_t *)(board->base + reg);

        val = htonl(val);

        addr[1] = val & 0xffff;
	addr[0] = val >> 16;
}

static int board_wr2rf_init(struct board *board_base,
                            int *argc, char *argv[])
{
	struct board_cernvme *board = (struct board_cernvme *)board_base;

        unsigned vme_addr;

        if (*argc > 2
            && (!strcmp(argv[1], "-s") || !strcmp(argv[1], "--slot"))) {
                char *e;
                unsigned slot;

                remove_arg1(argc, argv);
                slot = strtoul(argv[1], &e, 0);
                if (*e != 0) {
                        fprintf(stderr, "invalid slot '%s'\n", argv[1]);
                        return -1;
                }
                vme_addr = slot << 19;
                remove_arg1(argc, argv);
        }
        else {
                fprintf(stderr, "missing slot number for wr2rf\n");
                return -1;
        }

        return cernvme_map(board, 0x39, 16, vme_addr, 0x2000);
}

static void board_wr2rf_help(void)
{
        printf("wr2rf board (using CERN-vme bridge)\n");
        printf(" -s, --slot ADDR      board slot (512KB steps)\n");
}

static struct board_cernvme board_wr2rf =
{
	{
		{
			"wr2rf",
			board_wr2rf_init,
			board_cernvme_fini,
			board_wr2rf_help,
			wr2rf_readl,
			wr2rf_writel
		},
		NULL,
		0,
		NULL,
		0
	},
};
#endif

static struct board *boards[] = {
        &board_pci.parent.parent,
        &board_spec.parent.parent,
#ifdef SUPPORT_ERTM
	&board_ertm14.parent,
#endif
#ifdef SUPPORT_CERN_VMEBRIDGE
        &board_cernvme.parent.parent,
        &board_wr2rf.parent.parent,
#endif
        NULL
};

static struct board *find_board(const char *name)
{
        struct board *b;

        for (unsigned i = 0; (b = boards[i]); i++)
                if (!strcmp(b->name, name))
                        return b;
        fprintf(stderr,
                "board '%s' is unknown, try %s board\n",
                name, progname);
        return NULL;
}

static int board_open(int *argc, char *argv[])
{
	if (*argc > 2 && !strcmp(argv[1], "-b")) {
                struct board *b;
		/* Board selection */
		remove_arg1(argc, argv);
                b = find_board(argv[1]);
                if (b == NULL)
                        return -1;
                board = b;
		remove_arg1(argc, argv);
	}
	else
		board = &board_pci.parent.parent;

	return board->init(board, argc, argv);
}

static void wrc_cpu_reset(struct board *board, unsigned int rst)
{
	board->writel (board, OFFSET_CPU_CSR + WRC_CPU_CSR_REG_RESET, rst);
}

static void wrc_write_uaddr(struct board *board, unsigned int addr)
{
	board->writel(board, OFFSET_CPU_CSR + WRC_CPU_CSR_REG_UADDR, addr >> 2);
}

static void wrc_write_udata(struct board *board, uint32_t data)
{
	board->writel(board, OFFSET_CPU_CSR + WRC_CPU_CSR_REG_UDATA, data);
}

static uint32_t wrc_read_udata(struct board *board)
{
	return board->readl(board, OFFSET_CPU_CSR + WRC_CPU_CSR_REG_UDATA);
}

static int wrc_write_buf(struct board *board,
                         const unsigned char *buf,
                         unsigned len,
                         unsigned addr)
{
	if ((len & 0x03) != 0 || (addr & 0x03) != 0)
		abort();

	while (len > 0) {
		uint32_t v;

		wrc_write_uaddr(board, addr);

		/* Use BE.  */
		v = (buf[3] << 0)
			| (buf[2] << 8)
			| (buf[1] << 16)
			| (buf[0] << 24);
		wrc_write_udata(board, v);

		if (verbose)
			printf ("Write %08x at %08x\n", v, addr);

                if (flag_check) {
                        uint32_t r;
                        wrc_write_uaddr(board, addr);
                        r = wrc_read_udata(board);
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

static Elf32_Half read_elf_half (const Elf32_Half *v)
{
  const unsigned char *p = (const unsigned char *)v;
  return p[0] | (p[1] << 8);   /* LE  */
}

static Elf32_Word read_elf_word (const Elf32_Word *v)
{
  const unsigned char *p = (const unsigned char *)v;
  return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24);   /* LE  */
}

static int wrc_load_elf(struct board *board, const char *filename, int fd)
{
        Elf32_Ehdr ehdr;
        unsigned poff;
        unsigned pnum;
        //unsigned memsz;
        unsigned loff;
        unsigned i;

        if (lseek(fd, 0, SEEK_SET) != 0
            || read (fd, &ehdr, sizeof (ehdr)) != sizeof(ehdr)) {
                fprintf (stderr, "cannot read ELF header of %s\n", filename);
                return -1;
        }
        if (ehdr.e_ident[EI_MAG0] != ELFMAG0
            || ehdr.e_ident[EI_MAG1] != ELFMAG1
            || ehdr.e_ident[EI_MAG2] != ELFMAG2
            || ehdr.e_ident[EI_MAG3] != ELFMAG3) {
                fprintf (stderr, "file %s is not an ELF file\n", filename);
                return -1;
        }

        if (ehdr.e_ident[EI_CLASS] != ELFCLASS32
            || ehdr.e_ident[EI_DATA] != ELFDATA2LSB
            || ehdr.e_ident[EI_VERSION] != EV_CURRENT) {
                fprintf (stderr, "file %s is not expect ELF class\n", filename);
                return -1;
        }

        if (read_elf_half (&ehdr.e_type) != ET_EXEC
            || read_elf_half (&ehdr.e_machine) != 0xf3
            || read_elf_word (&ehdr.e_version) != EV_CURRENT) {
                fprintf (stderr,
                         "file %s is not a risc-v executable\n", filename);
                return -1;
        }

        if (read_elf_half (&ehdr.e_phentsize) != sizeof (Elf32_Phdr)) {
                fprintf (stderr, "file %s has bad phdr size\n", filename);
                return -1;
        }

        pnum = read_elf_half (&ehdr.e_phnum);

        if (read_elf_word (&ehdr.e_entry) != 0) {
                fprintf (stderr, "file %s entry point is not 0\n", filename);
                return -1;
        }

        poff = read_elf_word (&ehdr.e_phoff);

        loff = 0;
        for (i = 0; i < pnum; i++) {
                Elf32_Phdr phdr;
                unsigned sz;
                unsigned vaddr;
                unsigned char buf[4096];
                unsigned l, len;

                if (lseek (fd, poff + i * sizeof(Elf32_Phdr), SEEK_SET) < 0
                    || read (fd, &phdr, sizeof (phdr)) != sizeof(phdr)) {
                        fprintf(stderr,
                                "%s: cannot read program header\n", filename);
                        return -1;
                }
                if (read_elf_word (&phdr.p_type) != PT_LOAD)
                        continue;

                sz = read_elf_word (&phdr.p_filesz);
                if (sz == 0)
                        continue;
                //memsz = read_elf_word (&phdr.p_memsz);
                loff = read_elf_word (&phdr.p_offset);
                vaddr = read_elf_word (&phdr.p_vaddr);
                if (lseek (fd, loff, SEEK_SET) < 0) {
                        fprintf(stderr,
                                "%s: cannot seek to program content %i\n",
                                filename, i);
                        return -1;
                }

                sz = (sz + 3) & ~3;

                len = 0;
                while (len < sz) {
                        l = sz - len;
                        if (l > sizeof(buf))
                                l = sizeof(buf);
                        if (read (fd, buf, l) != l) {
                                fprintf(stderr,
                                        "%s: cannot read program\n", filename);
                                return -1;
                        }

                        if (wrc_write_buf(board, buf, l, vaddr + len) < 0)
                                return -1;
                        len += l;
                }

                /* TODO: do we want to clear until memsz ? */
        }
        return 0;
}

static int wrc_load_firmware(struct board *board, const char *filename)
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
                if (wrc_load_elf(board, filename, fd) < 0)
                        goto err_close;
	}
        else {
                addr = 0;
                if (wrc_write_buf(board, hdr, sizeof(hdr), addr) != 0)
                        goto err_close;
                addr += sizeof (hdr);

                while (1) {
                        res = read(fd, buf, sizeof(buf));
                        if (res <= 0)
                                break;
                        if (wrc_write_buf(board, buf, res, addr) != 0)
                                goto err_close;
                        addr += res;
                }
                printf ("%u KB written\n", addr / 1024);
        }

	close(fd);
	return 0;

err_close:
	close(fd);
	return -1;
}

static int wrc_save_firmware(struct board *board, const char *filename)
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
			wrc_write_uaddr(board, addr);
			v = wrc_read_udata(board);
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

static void wrc_dump(struct board *board, unsigned addr, unsigned len)
{
	unsigned off;

	off = 0;
	for (off = 0; off < len; off += 4) {
		uint32_t v;

		if ((off & 0x0f) == 0)
			printf ("%08x:", addr + off);

		wrc_write_uaddr(board, addr + off);

		v = wrc_read_udata(board);
		printf (" %08x", v);
		if ((off & 0x0f) == 0xc)
			printf ("\n");
	}
	if ((off & 0x0f) != 0xc)
		printf ("\n");
}

/* Extract the basename of :param name: */
static const char *get_basename(const char *name)
{
	const char *res = name;

	for (res = name; *name; name++)
		if (*name == '/')
			res = name + 1;
	if (*res)
		return res;
	else
		return name;
}

static int do_help(int argc, char *argv[])
{
	printf ("usage: %s [command] [-b BOARD] [OPTIONS...]\n", progname);
	printf ("command is one of:\n");
	for (unsigned i = 0; tools[i]; i++)
		printf(" %-18s - %s\n", tools[i]->name, tools[i]->short_help);
	return 0;
}

static int do_version(int argc, char *argv[])
{
	printf ("version 1.0\n");
	return 0;
}

static void help_load(void)
{
        printf("usage: %s load BOARD-OPTIONS FILENAME\n", progname);
        printf("Load FILENAME into WR cpu and restart the code\n");
}

static int do_load(int argc, char *argv[])
{
	int c;
        int status;
	const char *filename;
	enum { CMD_LOAD, CMD_DUMP, CMD_SAVE } cmd;

	/* Decode board options and open the board. */
	if (board_open(&argc, argv) < 0)
		return 1;

	status = 0;

	cmd = CMD_LOAD;
	while ((c = getopt(argc, argv, "vdsc")) != -1) {
		switch (c) {
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
		help_load();
		return 2;
	}
	filename = argv[optind];

	/* Reset */
	wrc_cpu_reset(board, 1 << 0);

	switch (cmd) {
	case CMD_LOAD:
		/* Load */
		if (wrc_load_firmware (board, filename) < 0)
                        status = 1;
		break;
	case CMD_SAVE:
		/* Save */
		wrc_save_firmware (board, filename);
		break;
	case CMD_DUMP:
		/* TODO: specify offset and length */
		wrc_dump(board, 0, 0x200);
		break;
	}

	/* Start */
	wrc_cpu_reset(board, 0);

        board->fini(board);

	return status;
}

static void help_vuart(void)
{
	fprintf(stderr, "%s BOARD-OPTIONS [-k] [-c <cmd>] [-r] [-t <timeout>]\n", progname);
	fprintf(stderr, " -k keep terminal\n");
	fprintf(stderr, " -c <cmd> execute command\n");
	fprintf(stderr, " -t <timeout> set a timeout to execute a command\n");
	fprintf(stderr, " -r do not expect stdin (may be useful for scripts),"
                        "    conflicts with -c\n");
}

static uint32_t vuart_readl(struct board *board, int reg)
{
	return board->readl(board, reg | OFFSET_UART);
}


static void vuart_writel(struct board *board, uint32_t value, int reg)
{
	board->writel(board, reg | OFFSET_UART, value);
}

static int wr_vuart_rx(struct board *board)
{
	int rdr = vuart_readl(board, UART_REG_HOST_RDR );
	return (rdr & UART_HOST_RDR_RDY) ? UART_HOST_RDR_DATA_R(rdr) : -1;
}

/**
 * It transmits a single byte
 * @param[in] vuart token from dev_map()
 */
static void wr_vuart_tx(struct board *board, char data)
{
	int sr = vuart_readl(board, UART_REG_SR );

	while(sr & UART_SR_RX_RDY)
		 sr = vuart_readl(board, UART_REG_SR );

	vuart_writel(board, UART_HOST_TDR_DATA_W(data), UART_REG_HOST_TDR );
}

/**
 * It reads a number of bytes and it stores them in a given buffer
 * @param[in] vuart token from dev_map()
 * @param[out] buf destination for read bytes
 * @param[in] size numeber of bytes to read
 *
 * @return the number of read bytes
 */
static size_t wr_vuart_read(struct board *board, char *buf, size_t size)
{
	size_t s = size, n_rx = 0;
	int8_t c;

	while(s--) {
		c =  wr_vuart_rx(board);
		if(c < 0)
			return n_rx;
		*buf++ = c;
		n_rx ++;
	}
	return n_rx;
}

/**
 * It flush vuart buffer.
 *
 * @param[in] vuart token from dev_map()
 *
 */
static void wr_vuart_flush(struct board *board)
{
	char rx;

	while(wr_vuart_read(board,&rx,1) == 1) {}
}

/**
 * It writes a number of bytes from a given buffer
 * @param[in] vuart token from dev_map()
 * @param[in] buf buffer to write
 * @param[in] size numeber of bytes to write
 */
static void wr_vuart_write(struct board *board, char *buf, size_t size)
{
	while(size--)
		wr_vuart_tx(board, *buf++);
}

static void wrpc_vuart_set_tty_raw(struct termios *old_termios)
{
  	struct termios newkey;

	tcgetattr(STDIN_FILENO,old_termios);
	memcpy(&newkey, old_termios, sizeof(struct termios));
	newkey.c_cflag = B9600 | CS8 | CLOCAL | CREAD;
	newkey.c_iflag = IGNPAR;
	newkey.c_oflag = 0;
	newkey.c_lflag = ISIG;  /* Keep C-c, C-z, ... */
	tcflush(STDIN_FILENO, TCIFLUSH);
	tcsetattr(STDIN_FILENO,TCSANOW,&newkey);
}

static void wrpc_vuart_restore_tty(struct termios *old_termios)
{
	tcsetattr(STDIN_FILENO, TCSANOW, old_termios);
}

static time_t get_running_secs(void)
{
        struct timeval now;

        gettimeofday(&now, NULL);
        return now.tv_sec;
}

static void wrpc_vuart_term(struct board *board,
                            int keep_term,
                            unsigned timeout)
{
	struct termios oldkey;
	int need_exit = 0;
	fd_set fds;
	int ret;
	unsigned char tx;
	int rx;
        time_t start_time;

	fprintf(stderr, "[press C-a to exit]\n");

	if(!keep_term)
		wrpc_vuart_set_tty_raw(&oldkey);

        if (timeout)
                start_time = get_running_secs();

	while(!need_exit) {
		struct timeval tv = {0, 10000};

		FD_ZERO(&fds);
		FD_SET(STDIN_FILENO, &fds);

		/*
		 * Check if the STDIN has characters to read
		 * (what the user writes)
		 */
		ret = select(STDIN_FILENO + 1, &fds, NULL, NULL, &tv);
		switch (ret) {
		case -1:
			perror("select");
			break;
		case 0: /* timeout */
			break;
		default:
			if(!FD_ISSET(STDIN_FILENO, &fds))
				break;
			/* The user wrote something */
			do {
				ret = read(STDIN_FILENO, &tx, 1);
			} while (ret < 0 && errno == EINTR);
			if (ret != 1) {
				fprintf(stderr, "nothing to read. Port disconnected?\n");
				need_exit = 1; /* kill */
			}
			/* If the user character is C-a, then kill */
			if(tx == '\x01') {
				need_exit = 1;
				break;
			}

			wr_vuart_tx(board, tx);
			break;
		}

		/* Print all the incoming characters */
		while((rx = wr_vuart_rx(board)) > 0) {
			putchar(rx);
		}
		fflush(stdout);

                if (timeout && get_running_secs() >= start_time + timeout)
                        break;
	}

	if(!keep_term)
		wrpc_vuart_restore_tty(&oldkey);
}

static void wrpc_vuart_only_read(struct board *board,
                            unsigned timeout)
{
	int need_exit = 0;
	int rx;
	time_t start_time;

	fprintf(stderr, "[press C-a to exit]\n");

	if (timeout)
		start_time = get_running_secs();

	while(!need_exit) {
		/* Print all the incoming characters */
		while((rx = wr_vuart_rx(board)) > 0) {
			putchar(rx);
		}
		fflush(stdout);
		usleep(10);

		if (timeout && get_running_secs() >= start_time + timeout)
			break;
	}
}

static void wrpc_vuart_command(struct board *board, char *command)
{
	//above is place for old and new port settings for keyboard teletype
	int cmd_len = 0;
	char *prompt = VUART_CMD_PROMPT;
	int i_prompt = 0;
	int i;
	int rx;

	/* Flush Vuart before sending command */
	wr_vuart_flush(board);
	/* Send command */
	cmd_len = strlen(command);
	wr_vuart_write(board, command, cmd_len);
	/* Flush command echo */
	wr_vuart_flush(board);
	/* Send end character */
	wr_vuart_tx(board, VUART_EOL);
	/* Wait for a while before reading command results */
	usleep(VUART_CMD_USLEEP);
	/* Discard characters until end of line control one */
	while((rx = wr_vuart_rx(board)) > 0) {
		if(rx == VUART_EOL)
			break;
	}

	while(1) {
		/* Print all the incoming characters */
		rx = wr_vuart_rx(board);
		if (rx < 0) {
			usleep(10);
			continue;
		}

		/* Prompt detection, skip characters */
		if (rx == prompt[i_prompt]) {
			i_prompt++;
			/* Prompt detected! */
			if(i_prompt == strlen(prompt))
				return;
		} else {
			/* Check if some previous characters have been skipped
			   by prompt detector code and print them */
			for(i = 0 ; i < i_prompt ; i++)
				putchar(prompt[i]);
			/* Reset prompt detector */
			i_prompt = 0;
			/* Print current character */
			putchar(rx);
			fflush(stdout);
		}
	}
}


static int do_vuart(int argc, char *argv[])
{
	char c;
	int keep_term = 0;
	char *cmd = NULL;
        unsigned timeout = 0;
	int read_only = 0;

	if (board_open(&argc, argv) < 0)
		return 1;

	/* Parse specific args */
	while ((c = getopt (argc, argv, "c:kt:r")) != -1) {
		switch (c) {
		case 'c':
			/* Enable command mode */
			cmd = optarg;
			break;
		case 'k':
			keep_term = 1;
			break;
                case 't':
                        timeout = atoi(optarg);
                        break;
		case 'r':
			read_only = 1;
                        break;
		case '?':
			break;
		}
	}

	if (cmd && read_only) {
		perror("-r conficts with -c\n");
		return 1;
	}

	if (read_only)
		wrpc_vuart_only_read(board, timeout);
	else if (cmd)
		wrpc_vuart_command(board, cmd);
	else
		wrpc_vuart_term(board, keep_term, timeout);

	board->fini(board);

	return 0;
}

static void help_info(void)
{
	printf("usage: %s info\n", progname);
	printf("display board info\n"
	       "also useful to check mapping\n");
}

static int do_info(int argc, char *argv[])
{
	unsigned hwfr;
	unsigned hwir;

	if (board_open(&argc, argv) < 0)
		return 1;

	hwfr = board->readl(board, OFFSET_SYSCON + offsetof(struct SYSC_WB, HWFR));
	printf ("hwfr=%08x:  "
		"memsize: %ukB,  storage: %u, storage sector size: %ukB\n",
		hwfr,
		SYSC_HWFR_MEMSIZE_R(hwfr) * 16,
		SYSC_HWFR_STORAGE_TYPE_R(hwfr),
		SYSC_HWFR_STORAGE_SEC_R(hwfr));

	hwir = board->readl(board, OFFSET_SYSCON + offsetof(struct SYSC_WB, HWIR));
	printf ("hwir=%08x:  ", hwir);
        for (unsigned i = 0; i < 4; i++) {
                unsigned c = (hwir >> (24 - i * 8)) & 0xff;
                putchar (c >= 32 && c < 127 ? c : '.');
        }
        printf ("\n");

	board->fini(board);

	return 0;
}

static int do_board(int argc, char *argv[])
{
        struct board *b;

        if (argc > 1) {
                b = find_board(argv[1]);
                if (b == NULL)
                        return 1;
                b->help();
        }
        else {
                printf ("List of boards:\n");
                for (unsigned i = 0; (b = boards[i]); i++)
                        printf(" %s\n", b->name);
        }
        return 0;
}

static void help_spll_recorder()
{
	fprintf(stderr, "SoftPLL debug/recorder tool. \n");
	fprintf(stderr, "This dumps the real-time SPLL traces (error values/DAC drive/events) into stdout for the purpose of further analysis/plotting. \n");

	fprintf(stderr, "Usage: %s spll-recorder [options]\n", progname);
	fprintf(stderr, "        -u <undersampling factor>\n");
}

static const char *dbg_source_to_string(int src)
{
	switch (src)
	{
	case SPLL_DBG_SRC_HELPER:
		return "helper";
	case SPLL_DBG_SRC_MAIN:
		return "main";
	case SPLL_DBG_SRC_AUX(0):
		return "aux0";
	case SPLL_DBG_SRC_AUX(1):
		return "aux1";
	case SPLL_DBG_SRC_AUX(2):
		return "aux2";
	case SPLL_DBG_SRC_AUX(3):
		return "aux3";
	case SPLL_DBG_SRC_EXT:
		return "ext";
	case SPLL_DBG_SRC_RAW:
		return "raw";
	default:
		return "<unknown?>";
	}
}

static const char *dbg_signal_to_string(int src)
{
	switch (src)
	{
	case SPLL_DBG_SIGNAL_ERR:
		return "err";
	case SPLL_DBG_SIGNAL_Y:
		return "y";
	case SPLL_DBG_SIGNAL_PERIOD:
		return "period";
	case SPLL_DBG_SIGNAL_REF:
		return "ref";
	case SPLL_DBG_SIGNAL_TAG:
		return "tag";
	case SPLL_DBG_SIGNAL_SAMPLE_ID:
		return "sample";
	case SPLL_DBG_SIGNAL_TIME_MS:
		return "time_ms";
	case SPLL_DBG_SIGNAL_PHASE_CURRENT:
		return "phase_current";
	case SPLL_DBG_SIGNAL_PHASE_TARGET:
		return "phase_target";
	case SPLL_DBG_SIGNAL_SRC:
		return "source";
	default:
		return "<unknown?>";
	}
}

static const char *dbg_event_to_string(int src)
{
	switch (src)
	{
	case SPLL_DBG_EVT_GAIN_SWITCH:
		return "gain-switch";
	case SPLL_DBG_EVT_LOCK_ACQUIRED:
		return "lock-acquired";
	case SPLL_DBG_EVT_LOCK_LOSS:
		return "lock-lost";
	case SPLL_DBG_EVT_START:
		return "start";
	default:
		return "<unknown?>";
	}
}

static int32_t signext32(uint32_t in, int bit)
{
	uint32_t mask = ~((1 << bit) - 1);
	if (in & (1 << bit))
		return in | mask;
	else
		return in;
}

static int prev_src = -1;
static volatile int kill_acquisition = 0;

void spll_sighandler(int sig)
{
	fprintf(stderr, "Signal caught: %d\n", sig);
	kill_acquisition = 1;
}

void spll_dump_debug_data(const uint32_t *buf, size_t size)
{
	while (size--)
	{
		uint32_t x = *buf++;

		int sig = SPLL_DBG_EXTRACT_SIGNAL(x);
		int src = SPLL_DBG_EXTRACT_SOURCE(x);
		uint32_t value_raw = SPLL_DBG_EXTRACT_VALUE(x);
		int32_t value;

		switch (sig)
		{
		case SPLL_DBG_SIGNAL_ERR:
			value = signext32(value_raw, 23);
			break;
		default:
			value = value_raw;
		};

		if (prev_src != src)
		{
			printf("%s ", dbg_source_to_string(src));
			prev_src = src;
		}

		if (sig == SPLL_DBG_SIGNAL_EVENT)
		{
			printf("event=%s ", dbg_event_to_string(value));
		}

		printf("%s=%d ", dbg_signal_to_string(sig),
			   value);

		if (SPLL_DBG_IS_LAST_RECORD(x))
		{
			printf("\n");
			prev_src = -1;
		}
	}
}

#ifdef SUPPORT_ERTM
void spll_readout_ertm14(struct board_ertm14* board, int undersample )
{

	int r = ertm_configure_spll_debug_dump(board->handle, 1, undersample);
	if (r)
		perror("ertm_configure_spll_debug_dump()");

	for (;;)
	{
		uint32_t buf[16384];
		size_t buf_size = 16384;
		int r = ertm_read_spll_debug_data(board->handle, buf, &buf_size);
		if (r >= 0)
		{
			spll_dump_debug_data(buf, buf_size);
		}

		if (kill_acquisition)
			break;
	}

	r = ertm_configure_spll_debug_dump(board->handle, 0, 0);
	if (r)
		perror("ertm_configure_spll_debug_dump()");

	fprintf(stderr, "ertm14: stopping SPLL logging...\n");
}
#endif

void spll_readout_direct(struct board* board )
{

	// purge the SPLL debug FIFO
	int dummy;
	for(;;)
	{
		uint32_t r = board->readl(board, OFFSET_SOFTPLL + offsetof( struct SPLL_WB, DFR_HOST_CSR ) );
		if (r & SPLL_DFR_HOST_CSR_EMPTY)
			break;

		dummy = board->readl(board, OFFSET_SOFTPLL + offsetof( struct SPLL_WB, DFR_HOST_R0 ) );
		(void) dummy;
	}


	for (;;)
	{
		uint32_t buf[16384];
		size_t buf_size = 16384, cnt = 0;
		const size_t max_record_size = 256;
		int got_a_full_record = 1;

		while( cnt < buf_size - max_record_size )
		{

			uint32_t fifo_sr = board->readl(board, OFFSET_SOFTPLL + offsetof( struct SPLL_WB, DFR_HOST_CSR ) );



			if( got_a_full_record && ( fifo_sr & SPLL_DFR_HOST_CSR_EMPTY ) )
				break;
			else
			{
				do {
					fifo_sr = board->readl(board, OFFSET_SOFTPLL + offsetof( struct SPLL_WB, DFR_HOST_CSR ) );
				} while( fifo_sr & SPLL_DFR_HOST_CSR_EMPTY );
			}

			uint32_t r = board->readl(board, OFFSET_SOFTPLL + offsetof( struct SPLL_WB, DFR_HOST_R0 ) );
			buf[cnt++] = r;
			got_a_full_record = SPLL_DBG_IS_LAST_RECORD(r) ? 1 : 0;
		}

		if( cnt > 0 )
			spll_dump_debug_data(buf, cnt);
	}
}


static int do_spll_recorder(int argc, char *argv[])
{
	int is_ertm = 0;
	int c;
	int undersample __attribute__((unused)) = 20;


	if (board_open(&argc, argv) < 0)
		return 1;

	/* Parse specific args */
	while ((c = getopt (argc, argv, "u:b:he:")) != -1) {
		switch (c) {
		case 'u':
			/* Enable command mode */
			undersample = atoi(optarg);
			break;
		case 'h':
			help_spll_recorder();
			break;
		case '?':
		default:
			break;
		}
	}

	is_ertm = !strcmp( board->name, "ertm14" );
	if(is_ertm)
	{
#ifdef SUPPORT_ERTM
		signal(SIGINT, spll_sighandler);
		signal(SIGTERM, spll_sighandler);

		spll_readout_ertm14( (struct board_ertm14*) board, undersample );
#endif
	}
	else
	{
		spll_readout_direct( (struct board*) board );
	}

	board->fini(board);

	return 0;
}


#define GDB_PACKET_SIZE_MAX 2048

/**
 * struct gdb_packet - GDB packet
 * @data: message exchanged with GDB
 * @size: length in bytes
 */
struct gdb_packet {
	char data[GDB_PACKET_SIZE_MAX];
	size_t size;
};

/**
 * struct dbg_port - descriptor to handle connection
 * @addr: Mock Turtle virtual address
 * @cpu: CPU index
 * @fd: socket file descriptor
 */
struct dbg_port {
	/* For debug */
	uint8_t cpu;
	int fd;
        unsigned flag_term;
};

typedef int (gdb_command_t)(struct dbg_port *dbg,
                            struct gdb_packet *out,
                            struct gdb_packet *in);

/**
 * Read value from the Debug Port
 */
static uint32_t dbg_readl(struct dbg_port *dbg, uint32_t reg)
{
        return board->readl(board, reg | OFFSET_CPU_CSR);
}

/**
 * Write value to the Debug Port
 */
static void dbg_writel(struct dbg_port *dbg,
                       uint32_t reg, uint32_t val)
{
        board->writel(board, reg | OFFSET_CPU_CSR, val);
}

/**
 * Control CPU reset
 */
static void dbg_set_cpu_reset(struct dbg_port *dbg, unsigned int rst)
{
	dbg_writel (dbg, WRC_CPU_CSR_REG_RESET, rst);
}

static uint32_t dbg_get_cpu_reset(struct dbg_port *dbg)
{
	return dbg_readl (dbg, WRC_CPU_CSR_REG_RESET);
}

/**
 * Read mail-box
 * @dbg: debug port
 *
 * Return value read
 */
static uint32_t dbg_read_mbx(struct dbg_port *dbg)
{
	uint32_t reg;

	reg = WRC_CPU_CSR_REG_DBG_CORE0_MBX;
	reg += sizeof(uint32_t) * dbg->cpu;

	return dbg_readl(dbg, reg);
}

/**
 * Write mail-box
 * @dbg: debug port
 * @val: value to write
 */
static void dbg_write_mbx(struct dbg_port *dbg, uint32_t val)
{
	uint32_t reg;

	reg = WRC_CPU_CSR_REG_DBG_CORE0_MBX;
	reg += sizeof(uint32_t) * dbg->cpu;

	dbg_writel(dbg, reg, val);
}

/**
 * Execute one instructions
 * @dbg: debug port
 * @insn: instruction to execute
 */
static void dbg_exec_insn(struct dbg_port *dbg, uint32_t insn)
{
	uint32_t reg;

	reg = WRC_CPU_CSR_REG_DBG_CORE0_INSN;
	reg += sizeof(uint32_t) * dbg->cpu;

	dbg_writel(dbg, reg, insn);
}

/**
 * Execute instruction to copy a register to the mail-box
 * @dbg: debug port
 * @reg: register index
 */
static void dbg_exec_reg_to_mbx(struct dbg_port *dbg, uint32_t reg)
{
	dbg_exec_insn(dbg, 0x7D001073 | (reg << 15));
}

/**
 * Execute instruction to the mail-box to a register
 * @dbg: debug port
 * @reg: register index
 */
static void dbg_exec_mbx_to_reg(struct dbg_port *dbg, uint32_t reg)
{
	dbg_exec_insn(dbg, 0x7D002073 | (reg << 7));
}

/**
 * Execute NOP instruction
 * @dbg: debug port
 */
static void dbg_exec_nop(struct dbg_port *dbg)
{
	dbg_exec_insn(dbg, 0x00000013);
}

/**
 * Check if MockTurtle CPU is in debug mode
 * @dbg: debug port
 *
 * Return true when it is in debug mode
 */
static bool dbg_in_debug_mode(struct dbg_port *dbg)
{
	uint32_t status;

	status = dbg_readl(dbg, WRC_CPU_CSR_REG_DBG_STATUS);

	return ((status >> dbg->cpu) & 1);
}

/**
 * Set MockTurtle CPU in debug mode
 * @dbg: debug port
 *
 * Return 0 on success, -1 on error and errno is appropriately set
 */
static int dbg_debug_mode_force_set(struct dbg_port *dbg)
{
	int retry;

	if (dbg_in_debug_mode(dbg))
		return 0;
	dbg_writel(dbg, WRC_CPU_CSR_REG_DBG_FORCE, (1 << dbg->cpu));
	/* wait to debug to be ready max ~5s */
	retry = 5000;
	while (retry >= 0) {
		struct timespec ts = {0, 1000000};

		nanosleep(&ts, NULL);
		if (dbg_in_debug_mode(dbg))
			break;
		retry--;
	}

	/* Remove the reset, otherwise the cpu won't be anymore in debug
	   mode.  */
	if (dbg_get_cpu_reset(dbg) != 0) {
		if (!dbg_in_debug_mode(dbg))
			fprintf(stderr, "Huhh, cpu not in debug\n");
		fprintf(stderr, "CPU under reset\n");
		dbg_set_cpu_reset(dbg, 0);
		if (!dbg_in_debug_mode(dbg))
			fprintf(stderr, "Huhh, cpu not anymore in debug\n");
	}

	dbg_writel(dbg, WRC_CPU_CSR_REG_DBG_FORCE, 0);

	if (retry < 0) {
		errno = ETIME;
		return -1;
	}
	return 0;
}

/**
 * Read from a CPU register
 * @dbg: debug port
 * @reg: register number [0, 31]
 *
 * Return: the register content
 */
static uint32_t dbg_read_reg(struct dbg_port *dbg, int reg)
{
	if (verbose > 2)
		printf("dbg_read_reg %d\n", reg);
	dbg_exec_reg_to_mbx(dbg, reg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);

	return dbg_read_mbx(dbg);
}

/**
 * Write in a CPU register
 * @dbg: debug port
 * @reg: register number [0, 31]
 * @val: value
 */
static void dbg_write_reg(struct dbg_port *dbg,
			       int reg, uint32_t val)
{
	dbg_write_mbx(dbg, val);
	dbg_exec_mbx_to_reg(dbg, reg);
}

/**
 * Copy PC to RA register
 * @dbg: debug port
 *
 * Return PC value
 */
static uint32_t dbg_pc_read_via_ra(struct dbg_port *dbg)
{
	if (verbose > 2)
		printf("dbg_pc_read_via_ra\n");
	dbg_exec_insn(dbg, 0x000000ef); /* ra = pc + 4 */
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_reg_to_mbx(dbg, 1);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	return (dbg_read_mbx(dbg) - 4) & 0xFFFFFFFF;
}

/**
 * Write PC using RA content register
 * @dbg: debug port
 */
static void dbg_pc_write_via_ra(struct dbg_port *dbg)
{
	dbg_exec_insn(dbg, 0x00008067); /* ret */
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
}

/**
 * Increase PC by 4
 * @dbg: debug port
 */
static void dbg_pc_advance_4(struct dbg_port *dbg)
{
	dbg_exec_insn(dbg, 0x00000263); /* beqz zero, +4 */
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
}

/**
 * Continue command
 */
static int gdb_handle_c(struct dbg_port *dbg,
                        struct gdb_packet *out,
                        struct gdb_packet *in)
{
	if (in->size > 1) {
		out->size = 0;
		return 0;
	}

	dbg_exec_insn(dbg, 0x00100073); /* ebreak */
	while (1) {
		int ret;
		struct pollfd p[2];

		/* Dump vuart. */
		if (dbg->flag_term) {
			while (1) {
				int rx = wr_vuart_rx(board);
				if (rx < 0)
					break;
				putchar(rx);
			}
			fflush(stdout);
		}

		if (dbg_in_debug_mode(dbg)) {
			/*
			 * TODO not clear but check twice due to possible
			 * race if the ebreak is not yet executed
			 */
			if (dbg_in_debug_mode(dbg)) {
				out->size = snprintf(out->data,
						     GDB_PACKET_SIZE_MAX,
						     "S05");
				break;
			}
		}

		p[0].fd = dbg->fd;
		p[0].events = POLLIN;
		p[0].revents = 0;

		if (dbg->flag_term) {
			p[1].fd = 0;
			p[1].events = POLLIN;
			p[1].revents = 0;
			ret = poll(p, 2, 100);
		}
		else
			ret = poll(p, 1, 1000);

		if (ret == 0)
			continue;
		if (ret < 0)
			break;

		if (dbg->flag_term && (p[1].revents & POLLIN)) {
			char c;
			if (read(0, &c, 1) == 1)
				wr_vuart_tx(board, c);
		}
		if (p[0].revents & POLLIN) {
			/* GDB wants something from us */
			ret = dbg_debug_mode_force_set(dbg);
			if (ret < 0)
				fprintf(stderr, "Failed to set debug mode\n");
			out->size = snprintf(out->data,
					     GDB_PACKET_SIZE_MAX,
					     "S02");
			break;
		}
	}

	return 0;
}

/**
 * Detach
 */
static int gdb_handle_D(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	dbg_exec_insn(dbg, 0x00100073); /* ebreak */
	out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX, "OK");

	return 0;
}

/**
 * Read all registers
 */
static int gdb_handle_g(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	uint32_t regs[32], pc;
	int i;

	out->size = 0;
	for (i = 0; i < 32; ++i) {
		regs[i] = dbg_read_reg(dbg, i);
		out->size += snprintf(out->data + out->size,
				      GDB_PACKET_SIZE_MAX,
				      "%08"PRIx32, htonl(regs[i]));
	}
	pc = dbg_pc_read_via_ra(dbg);
	out->size += snprintf(out->data + out->size,
			      GDB_PACKET_SIZE_MAX,
			      "%08"PRIx32, htonl(pc));
	dbg_write_reg(dbg, 1, regs[1]);

	return 0;
}

/**
 * Write all register
 */
static int gdb_handle_G(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	uint32_t regs[33]; /* 32 register, 1 PC */
	int i;

	if (in->size != (1 + 33 * 8)) {
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E01");
		return 0;
	}

	for (i = 0; i < 33; ++i) {
		int ret = sscanf(in->data + 1 + i * 8, "%08"SCNx32, &regs[i]);

		if (ret != 1) {
			out->size = snprintf(out->data,
					     GDB_PACKET_SIZE_MAX,
					     "E02");
			return 0;
		}
	}

	/* Register 32 is pc.  */
	dbg_write_reg(dbg, 1, ntohl(regs[32]));
	dbg_pc_write_via_ra(dbg);

	for (i = 1; i < 32; ++i)
		dbg_write_reg(dbg, i, ntohl(regs[i]));
	out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
			     "OK");

	return 0;
}

/**
 * Set thread for subsequent operations
 *
 * Partially supported
 */
static int gdb_handle_H(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	/* we just want to keep GDB quiet */
	if (strncmp(in->data, "Hg0", 3) == 0)
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "OK");
	else
		out->size = 0;

	return 0;
}

/**
 * Kill
 *
 * Not supported yet
 *
 * kill leave the CPU in its current state. In the next connection it
 * will restart exactly from that point and the core remains stopped.
 */
static int gdb_handle_k(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	return 0;
}

/**
 * Write data to memory
 */
static int gdb_handle_M(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	uint32_t addr, n;
	uint32_t a0, a1;
	char *indata;
	int ret;

	indata = strchr(in->data, ':');
	if (!indata) {
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E01");
		return 0;
	}
	indata++; /* skip ':' */
	ret = sscanf(in->data + 1, "%"SCNx32",%"SCNx32":", &addr, &n);
	if (ret != 2) {
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E02");
		return 0;
	}

	if (n * 2 != in->size - (indata - in->data)) {
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E03");
		return 0;
	}

	a0 = dbg_read_reg(dbg, 10);
	a1 = dbg_read_reg(dbg, 11);
	dbg_write_reg(dbg, 10, addr);
	if (addr % 4 == 0) {
		for (; n >= 4; n -= 4, indata += 8) {
			uint32_t w;

			ret = sscanf(indata, "%08"SCNx32, &w);
			if (ret != 1)
				break;

			dbg_write_reg(dbg, 11, ntohl(w));
			/* sw a1, 0(a0) */
			dbg_exec_insn(dbg, 0x00B52023);
			/* addi a0, a0, 4 */
			dbg_exec_insn(dbg, 0x00450513);
		}
	}
	for (; n > 0; --n, indata += 2) {
		uint32_t b;

		ret = sscanf(indata, "%02"SCNx32, &b);
		if (ret != 1)
			break;
		dbg_write_reg(dbg, 11, b);
		/* sb a1, 0(a0) */
		dbg_exec_insn(dbg, 0x00B50023);
		/* addi a0, a0, 4 */
		dbg_exec_insn(dbg, 0x00150513);
	}

	dbg_write_reg(dbg, 10, a0);
	dbg_write_reg(dbg, 11, a1);

	if (n > 0)
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E04");
	else
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "OK");

	return 0;
}

/**
 * Read data from memory
 */
static int gdb_handle_m(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	uint32_t addr, n;
	uint32_t a0, a1;
	int ret;

	ret = sscanf(in->data + 1, "%x,%x", &addr, &n);
	if (ret != 2) {
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E01");
		return 0;
	}
	a0 = dbg_read_reg(dbg, 10);
	a1 = dbg_read_reg(dbg, 11);
	dbg_write_reg(dbg, 10, addr);
	out->size = 0;
	for (; n > 0; --n) {
		uint8_t b;

		dbg_exec_insn(dbg, 0x00054583); /* lbu a1, 0(a0) */
		dbg_exec_insn(dbg, 0x00150513); /* addi a0, a0, 1 */
		b = dbg_read_reg(dbg, 11);
		out->size += snprintf(out->data + out->size,
				      GDB_PACKET_SIZE_MAX,
				      "%02"PRIx8, b);
	}

	dbg_write_reg(dbg, 10, a0);
	dbg_write_reg(dbg, 11, a1);

	return 0;
}

/**
 * Read a specific register
 */
static int gdb_handle_p(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	unsigned int val;
	int ret;

	ret = sscanf(in->data + 1, "%x", &val);
	if (ret != 1) {
		out->size = 0;
		return 0;
	}
	printf("0x%x\n", val);
	if (val == (0x301 + 65)) /* MISA CSR */
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "%08x",
				     (1 << 30) | (1 << ('I' - 65)));
	else
		out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
				     "E01");

	return 0;
}

/**
 * Write a specific register
 *
 *
 * Not supported yet
 */
static int gdb_handle_P(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	out->size = 0;

	return 0;
}

/**
 * Answer to qSupported request
 */
static int gdb_handle_q_supported(struct dbg_port *dbg,
				       struct gdb_packet *out,
				       struct gdb_packet *in)
{
	out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX,
			     "PacketSize=%x", GDB_PACKET_SIZE_MAX);

	return 0;
}

static int gdb_handle_qm(struct dbg_port *dbg,
			      struct gdb_packet *out,
			      struct gdb_packet *in)
{
	out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX, "S05");

	return 0;
}

static int gdb_handle_qRcmd(struct dbg_port *dbg,
			      struct gdb_packet *out,
			      struct gdb_packet *in)
{
	char buf[GDB_PACKET_SIZE_MAX / 2];
	unsigned len;

	/* Decode hex input (convert to bytes). 6 is the prefix 'qRcmd,' */
	for (len = 0; len < (in->size - 6) / 2; len++) {
		unsigned val;
		int ret;

		ret = sscanf(in->data + 6 + len * 2, "%02x", &val);
		if (ret != 1) {
			out->size = 0;
			return 0;
		}
		buf[len] = val;
	}
	buf[len] = 0;

	if (strcmp(buf, "help") == 0) {
		strcpy(buf, "usage: csr | reset | port | help\n");
	}
	else if (strcmp(buf, "csr") == 0) {
		uint32_t ra;
		uint32_t mepc, mstatus, mcause;
		ra = dbg_read_reg(dbg, 1);
		dbg_exec_insn(dbg, 0x341020f3); /* csrr ra,mepc */
		mepc = dbg_read_reg(dbg, 1);
		dbg_exec_insn(dbg, 0x342020f3); /* csrr ra,mcause */
		mcause = dbg_read_reg(dbg, 1);
		dbg_exec_insn(dbg, 0x300020f3); /* csrr ra,mstatus */
		mstatus = dbg_read_reg(dbg, 1);
		dbg_write_reg(dbg, 1, ra);
		snprintf(buf, sizeof(buf),
			 "mepc:    %08x\nmcause:  %08x\nmstatus: %08x\n",
			 mepc, mcause, mstatus);
	}
	else if (strcmp(buf, "reset") == 0) {
		/* Reset the cpu.  */
		dbg_set_cpu_reset(dbg, 1);
		/* Force debug mode, otherwire it is cleared by reset.  */
		dbg_writel(dbg, WRC_CPU_CSR_REG_DBG_FORCE, (1 << dbg->cpu));
		/* Release reset.  */
		dbg_set_cpu_reset(dbg, 0);
		/* Release force debug.  */
		dbg_writel(dbg, WRC_CPU_CSR_REG_DBG_FORCE, 0);
		if (!dbg_in_debug_mode(dbg))
		  fprintf(stderr, "Huhh, cpu not in debug\n");
		strcpy(buf, "board reset\n");
	}
	else if (strcmp(buf, "port") == 0) {
		snprintf(buf, sizeof(buf),
			 "rst: %04x\ndbg st: %04x\n",
			 dbg_readl (dbg, WRC_CPU_CSR_REG_RESET),
			 dbg_readl (dbg, WRC_CPU_CSR_REG_DBG_STATUS));
	}
	else {
		strcpy(buf,"unhandled mon command, try 'mon help'\n");
	}

	/* Encode to hex.  */
	for (len = 0; buf[len]; len++)
		sprintf(out->data + len * 2, "%02x", buf[len]);
	out->size = len * 2;
	return 0;
}

static int gdb_handle_q(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	if (strncmp(in->data, "qSupported:", 11) == 0)
		return gdb_handle_q_supported(dbg, out, in);
	else if (strncmp(in->data, "qm", 2) == 0)
		return gdb_handle_qm(dbg, out, in);
	else if (strncmp(in->data, "qRcmd,", 6) == 0)
		return gdb_handle_qRcmd(dbg, out, in);
	out->size = 0;

	return 0;
}

/**
 * Single step
 */
static int gdb_handle_s(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	uint32_t pc, npc, ra, insn;

	if (in->size > 1) {
		out->size = 0;
		return 0;
	}

	/* Get ra(x1) and pc  */
	ra = dbg_read_reg(dbg, 1);
	pc = dbg_pc_read_via_ra(dbg);

	/* Read the instruction to be executed (at pc) */
	dbg_write_reg(dbg, 1, pc);
	dbg_exec_insn(dbg, 0x0000A083) ;/* lw ra,0(ra) */
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	insn = dbg_read_reg(dbg, 1);
	if (verbose)
		fprintf(stdout, "execute: %08"PRIx32" at pc=%08"PRIx32,
			insn, pc);

	/* Restore ra */
	dbg_write_reg(dbg, 1, ra);

	/* Execute the instruction */
	dbg_exec_insn(dbg, insn);
	dbg_exec_nop(dbg);
	dbg_exec_nop(dbg);
	switch (insn & 0x77) {
	case 0x67: /* jump */
		/* Nothing to do, PC is always updated */
		break;
	case 0x63: /* branch */
		/* Read new PC */
		ra = dbg_read_reg(dbg, 1);
		npc = dbg_pc_read_via_ra(dbg);
		dbg_write_reg(dbg, 1, ra);
		/* In case of no change, the branch has not been taken,
		   so the PC needs to be updated to the next instruction.
		   If the branch has been taken, the PC has been updated.
		   NOTE: it doesn't work in case of conditional jump to the
		   current instruction.  Maybe decode the instruction
		   further. */
		if (npc == pc)
			dbg_pc_advance_4(dbg);
		break;
	default:
		/* The instruction has been executed, the pc needs to
		   be updated */
		dbg_pc_advance_4(dbg);
		break;
	}

	out->size = snprintf(out->data, GDB_PACKET_SIZE_MAX, "S05");

	return 0;
}

/**
 * vAttach command
 *
 * Not supported yet
 */
static int gdb_handle_v_attach(struct dbg_port *dbg,
				    struct gdb_packet *out,
				    struct gdb_packet *in)
{
	out->size = 0;
	return 0;
}

/**
 * vCont command
 *
 * Not supported yet
 */
static int gdb_handle_v_cont(struct dbg_port *dbg,
				  struct gdb_packet *out,
				  struct gdb_packet *in)
{
	out->size = 0;

	return 0;
}

/**
 * vCtrlC command
 *
 * Not supported yet
 */
static int gdb_handle_v_ctrlc(struct dbg_port *dbg,
				   struct gdb_packet *out,
				   struct gdb_packet *in)
{
	out->size = 0;

	return 0;
}

/**
 * v<name> commands
 */
static int gdb_handle_v(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	int ret = 0;

	if (strncmp(in->data, "vAttach", 7) == 0)
		ret = gdb_handle_v_attach(dbg, out, in);
	else if (strncmp(in->data, "vCont", 5) == 0)
		ret = gdb_handle_v_cont(dbg, out, in);
	else if (strncmp(in->data, "vCtrlC", 6) == 0)
		ret = gdb_handle_v_ctrlc(dbg, out, in);
	else if (strncmp(in->data, "vMustReplyEmpty:", 16) == 0)
		out->size = 0;
	else
		out->size = 0;

	return ret;
}

/**
 * Write binary data to memory
 *
 * Not supported yet
 */
static int gdb_handle_X(struct dbg_port *dbg,
			     struct gdb_packet *out,
			     struct gdb_packet *in)
{
	out->size = 0;

	return 0;
}

static gdb_command_t *gdb_packet_exec[] = {
	['c'] = gdb_handle_c,
	['D'] = gdb_handle_D,
	['g'] = gdb_handle_g,
	['G'] = gdb_handle_G,
	['H'] = gdb_handle_H,
	['k'] = gdb_handle_k,
	['M'] = gdb_handle_M,
	['m'] = gdb_handle_m,
	['p'] = gdb_handle_p,
	['P'] = gdb_handle_P,
	['q'] = gdb_handle_q,
	['s'] = gdb_handle_s,
	['v'] = gdb_handle_v,
	['v'] = gdb_handle_v,
	['X'] = gdb_handle_X,
	['?'] = gdb_handle_qm,
};

/**
 * Process incoming packet and generate the outcoming
 * @out: outgoing packet
 * @in: incoming packet
 *
 * Return: 0 on success, otherwise -1 and errno is appropriately set
 *
 * The function does not receive or send packets, it only processes them;
 * the caller will handle recv(2) and send(2)
 */
static int gdb_command(struct dbg_port *dbg,
		       struct gdb_packet *out,
		       struct gdb_packet *in)
{
	int cmd = in->data[0];
	gdb_command_t *exec;

	if (in->size == 0)
		return -1;

	exec = gdb_packet_exec[cmd];
	if (exec)
		return exec(dbg, out, in);
	out->size = 0;
	return 0;
}

static void debugger_print_packet(struct gdb_packet *pkt,
				       const char *dir)
{
	int i, start, end;

	switch (verbose) {
	case 0:
		return;
	case 1:
		start = 1;
		end = pkt->size - 3;
		break;
	default:
		start = 0;
		end = pkt->size;
		break;
	}

	fputs(dir, stdout);
	fputc(' ', stdout);
	for (i = start; i < end; ++i)
		fputc(pkt->data[i], stdout);
	fputc('\n', stdout);
	fflush(stdout);
}

/**
 * Calculate mod 256 checksum
 * @data: input data
 * @n: number of bytes
 *
 * Return: checksum value
 */
static uint8_t debugger_checksum(uint8_t *data, size_t n)
{
	uint8_t checksum = 0;
	int i;

	for (i = 0; i < n; ++i)
		checksum += data[i];

	return checksum & 0xFF;
}

/**
 * Receive a GDB packet
 * @fd: socket file descriptor
 * @pkt: packet
 *
 * Return: 0 on success, otherwise -1 and errno is appropriately set
 */
static int __debugger_recv(int fd, struct gdb_packet *pkt)
{
	pkt->size = 0;
	do {
		char c;
		int ret;
		struct pollfd p = {
				   .fd = fd,
				   .events = POLLIN,
				   .revents = 0,
		};

		ret = poll(&p, 1, 1000);
		if (ret < 0)
			return ret;
		if (ret == 0)
			continue;
		ret = recv(fd, &c, 1, 0);
		if (ret < 0)
			return -1;
		if (ret == 0) {
			errno = ENOTCONN;
			return -1;
		}
		/* FIXME should we control more ? */
		if (pkt->size == 0 && c != '$')
			continue; /* wait for the beginning */
		pkt->data[pkt->size] = c;
		pkt->size++;

		if (verbose > 3) {
			fprintf(stdout, "Building message: [%zu]: %s\n",
				pkt->size, pkt->data);
		}

		if (pkt->size > GDB_PACKET_SIZE_MAX - 1) {
			/* -1 to leave space for the string terminator */
			errno = EINVAL;
			return -1;
		}

	} while (!(pkt->size > 3 && pkt->data[pkt->size - 3] == '#'));

	return 0;
}

/**
 * Receive a GDB packet
 * @fd: socket file descriptor
 * @pkt: packet
 *
 * Return: 0 on success, otherwise -1 and errno is appropriately set
 */
static int debugger_recv(int fd, struct gdb_packet *pkt)
{
	uint8_t checksum_l, checksum_r;
	char ack[1];
	int ret;

	ret = __debugger_recv(fd, pkt);
	if (ret < 0)
		return ret;
	debugger_print_packet(pkt, "->");

	checksum_l = debugger_checksum((uint8_t *)(pkt->data + 1),
					    pkt->size - 4);

	ret = sscanf(pkt->data + pkt->size - 2, "%02"SCNx8, &checksum_r);
	if (ret != 1) {
		fprintf(stderr, "Received invalid checksum\n");
		return -1;
	}

	/* Remove checksum and special characters $payload#checksum */
	pkt->size -= 4;
	memmove(pkt->data, pkt->data + 1, pkt->size);
	pkt->data[pkt->size] = 0;

	if (checksum_l == checksum_r) {
		ack[0] = '+';
	} else {
		ack[0] = '-';
		if (verbose)
			fprintf(stderr,
				"Invalid checksum ' (L) %x != (R) %x'\n",
				checksum_l, checksum_r);
	}

	ret = send(fd, ack, 1, 0);
	if (ret != 1) {
		fputs("Failed to send acknowledge\n", stderr);
		errno = EIO;
		return -1;
	}

	return 0;
}

/**
 * Send a GDB packet
 * @fd: socket file descriptor
 * @pkt: packet
 *
 * Return: 0 on success, otherwise -1 and errno is appropriately set
 */
static int debugger_send(int fd, struct gdb_packet *pkt)
{
	uint8_t checksum_l;
	int ret;

	checksum_l = debugger_checksum((uint8_t *)pkt->data, pkt->size);

	/* Add checksum and special characters $payload#checksum */
	memmove(pkt->data + 1, pkt->data, pkt->size);
	pkt->data[0] = '$';
	snprintf(pkt->data + 1 + pkt->size, GDB_PACKET_SIZE_MAX,
		 "#%02x", checksum_l);
	pkt->size += 4; /* 1 $, 1 #, 2 checksum */

	debugger_print_packet(pkt, "<-");

	ret = send(fd, pkt->data, pkt->size, 0);
	if (ret < 0)
		return -1;
	if (ret != pkt->size) {
		errno = EIO;
		return -1;
	}

	return 0;
}

/**
 * Run GDB server
 * @addr: MMAP address
 *
 * Return: 0 on success, otherwise -1 and errno is appropriately set
 */
static int debugger_run(struct dbg_port *dbg)
{
	bool run = true;
	int ret;
	struct gdb_packet *pkt, *in, *out;

	pkt = calloc(2, sizeof(struct gdb_packet));
	if (!pkt) {
		fprintf(stderr, "Memory allocation failed: %s\n",
			strerror(errno));
		return -1;
	}
	in = &pkt[0];
	out = &pkt[1];

	ret = dbg_debug_mode_force_set(dbg);
	if (ret < 0) {
		fprintf(stderr, "Failed to set debug mode\n");
		return -1;
	}

	fputs("Start receiving messages from GDB\n", stdout);
	while (run) {
		memset(in, 0, sizeof(*in));
		memset(out, 0, sizeof(*out));

		ret = debugger_recv(dbg->fd, in);
		if (ret) {
			if (errno == ENOTCONN)
				run = false;
			else
				fprintf(stderr,
					"Failed to receive message: %s\n",
					strerror(errno));
			continue;
		}

		ret = gdb_command(dbg, out, in);
		if (ret < 0)
			continue;

		ret = debugger_send(dbg->fd, out);
		if (ret) {
			fprintf(stderr, "Failed to send message: %s\n",
				strerror(errno));
		}
	}

	free(pkt);

	return 0;
}

static void help_gdbserver(void)
{
	fprintf(stderr, "%s BOARD-OPTIONS [options]\n", progname);
	fprintf(stderr, " -p PORT       listen on tcp port PORT\n");
	fprintf(stderr, " -v            verbose\n");
	fprintf(stderr, " -t            enable terminal\n");
	fprintf(stderr, " -k            keep connection\n");
}

#define MEMPATH_LEN 128

static int do_gdbserver(int argc, char *argv[])
{
	int flag_keep = 0;
	int gdb_port = 7471;
	int c, ret, sfd, ret_exit = EXIT_SUCCESS, optval;
	struct dbg_port dbg;
	struct sockaddr_in server_addr;
	struct sockaddr_in client_addr;
	socklen_t client_len = sizeof(client_addr);

        /* Decode board options and open the board. */
        if (board_open(&argc, argv) < 0)
          return 1;

	memset(&dbg, 0, sizeof(dbg));
	while ((c = getopt(argc, argv, "p:vstk")) != -1) {
		switch (c) {
		case 'p':
			gdb_port = atoi(optarg);
			if (gdb_port == 0) {
				fprintf(stderr, "bad port value\n");
				exit(EXIT_FAILURE);
			}
			break;
		case 'v':
			verbose++;
			break;
		case 'k':
                        flag_keep = 1;
			break;
		case 't':
			dbg.flag_term = 1;
			break;
		case '?':
                        printf("%s: unknown option, try -h\n", argv[0]);
                        exit(1);
		}
	}

	sfd = socket(AF_INET, SOCK_STREAM, 0);
	if (sfd < 0) {
		fprintf(stderr, "Failed to open a socket: %s\n",
			strerror(errno));
		ret_exit = EXIT_FAILURE;
		goto out_sock;
	}

	optval = 1;
	ret = setsockopt(sfd, SOL_SOCKET, SO_REUSEADDR,
			 &optval, sizeof(optval));
	if (ret < 0) {
		fprintf(stderr, "Failed to set REUSEADDR option: %s\n",
			strerror(errno));
		ret_exit = EXIT_FAILURE;
		goto out_sock;
	}
	server_addr.sin_family = AF_INET;
	server_addr.sin_addr.s_addr = INADDR_ANY;
	server_addr.sin_port = htons(gdb_port);
	ret = bind(sfd, (struct sockaddr *)&server_addr, sizeof(server_addr));
	if (ret < 0) {
		fprintf(stderr, "Failed to bind to an *:%d: %s\n",
			gdb_port, strerror(errno));
		ret_exit = EXIT_FAILURE;
		goto out_sock;
	}

	ret = listen(sfd, 1);
	if (ret < 0) {
		fprintf(stderr, "Failed to listen: %s\n", strerror(errno));
		ret_exit = EXIT_FAILURE;
		goto out_bind;
	}

	do {
		printf ("Waiting for connection on port %d\n", gdb_port);

		dbg.fd = accept(sfd, (struct sockaddr *)&client_addr,
				&client_len);
		if (dbg.fd < 0) {
			fprintf(stderr, "Failed to accept: %s\n",
				strerror(errno));
			ret_exit = EXIT_FAILURE;
			break;
		}
		fprintf(stdout, "Accepted connection from %s\n",
			inet_ntoa(client_addr.sin_addr));

		ret = debugger_run(&dbg);
		if (ret < 0) {
			ret_exit = EXIT_FAILURE;
                        break;
		}
	} while (flag_keep);

out_bind:
out_sock:
	close(sfd);
        board->fini(board);
        return ret_exit;
}

static void help_wdiags(void)
{
	printf("usage: %s wdiags\n", progname);
	printf("display diagnostic registers\n");
}

#define WDIAG_REG(R) (OFFSET_WDIAGS + offsetof(struct wrc_diags, R))

static void unlock_diag(void)
{
        unsigned v;

	//reset snapshot bit & keep valid bit as it is
        v = board->readl(board, WDIAG_REG(CTRL));
        board->writel(board, WDIAG_REG(CTRL), v & WRC_DIAGS_CTRL_DATA_VALID);
}

static int lock_diag(void)
{
        unsigned v;

	//snapshot diag ( just raise snapshot bit)
        v = board->readl(board, WDIAG_REG(CTRL));
        if (0)
                printf("ctrl @%08x = %08x\n", (unsigned)WDIAG_REG(CTRL), v);
        board->writel(board, WDIAG_REG(CTRL), v | WRC_DIAGS_CTRL_DATA_SNAPSHOT);
        for (unsigned i = 10; i > 0; i--) {
                v = board->readl(board, WDIAG_REG(CTRL));
                if (v & WRC_DIAGS_CTRL_DATA_VALID)
                        return 0;
		usleep(1000);
        }
	fprintf(stderr, "timeout(10ms) expired while waiting for the valid bit "
		"for snapshot\n");
	return 1;
}

static void print_servo_status(uint32_t val)
{
	static const char * const sstat_str[] = {
		"Not initialized",
		"Sync ns",
		"Sync TAI",
		"Sync phase",
		"Track phase",
		"Wait offset stable",
	};

	printf("servo status:\t\t%s\n",
		sstat_str[val >> WRC_DIAGS_WDIAG_SSTAT_SERVOSTATE_SHIFT]);
}

static void print_port_status(uint32_t val)
{
	static int nbits = 2;
	static char *pstat_str[][2] = {
		//bit = 0     	 	bit = 1
		{"Link down", 		"Link up",},
		{"PLL not locked",	"PLL locked",},
	};
	int i, idx;

	printf("Port status:\t\t");
	for (i = 0; i < nbits; ++i) {
		idx = (val & (1 << i)) ? 1 : 0;
		printf("%s, ", pstat_str[i][idx]);
	}
	printf("\n");
}

static void print_ptp_state(uint32_t val)
{
	static const char * const ptpstat_str[] = {
		"None",
		"PPS initializing",
		"PPS faulty",
		"disabled",
		"PPS listening",
		"PPS pre-master",
		"PPS master",
		"PPS passive",
		"PPS uncalibrated",
		"PPS slave",
	};

	printf("PTP state:\t\t");
	if (val <= 9)
		printf("%s", ptpstat_str[val]);
	else if (val >= 100 && val <= 116)
		printf("WR STATES(see ppsi/ieee1588_types.h): %d", val);
	else
		printf("Unknown");
	printf("\n");
}

static void print_aux_state(uint32_t val)
{
	int nch = 8; //should be retrieved from a register
	int i;

	printf("Aux state:\t\t");
	for (i = 0; i < nch; i++) {
		if (val & (1 << i))
			printf("ch%d:enabled ", i);
	}
	printf("\n");
}

static void print_tx_frame_count(uint32_t val)
{
	printf("TX frame count:\t\t%d\n", val);
}

static void print_rx_frame_count(uint32_t val)
{
	printf("RX frame count:\t\t%d\n", val);
}

static void print_rx_error_count(uint32_t val)
{
	printf("RX error count:\t\t%d\n", val);
}

static void print_local_time(uint32_t sec_msw, uint32_t sec_lsw, uint32_t ns)
{
	uint64_t sec = (uint64_t)(sec_msw) << 32 | sec_lsw;
//	fprintf(stderr, "TAI time:\t\t %" PRIu64 "sec %d nsec\n",
//		sec, ns);
	printf("TAI time:\t\t%s", ctime((time_t *)&sec));
}

static void print_roundtrip_time(uint32_t msw, uint32_t lsw)
{
	uint64_t val = (uint64_t)(msw) << 32 | lsw;
	printf("Round trip time:\t%" PRIu64 " ps\n", val);
}

static void print_master_slave_delay(uint32_t msw, uint32_t lsw)
{
	uint64_t val = (uint64_t)(msw) << 32 | lsw;
	printf("Master slave delay:\t%" PRIu64 " ps\n", val);
}

static void print_link_asym(uint32_t val)
{
	printf("Total Link asymmetry:\t%d ps\n", val);
}

static void print_clock_offset(uint32_t val)
{
	printf("Clock offset:\t\t%d ps\n", val);
}

static void print_phase_setpoint(uint32_t val)
{
	printf("Phase setpoint:\t\t%d ps\n", val);
}

static void print_update_counter(uint32_t val)
{
	printf("Update counter:\t\t%d\n", val);
}

static void print_board_temp(uint32_t val)
{
        printf("temp:\t\t\t%d.%04d C\n", val >> 16,
               (int)((val & 0xffff) * 10 * 1000 >> 16));
}

static void print_aux_clock_status_single( int index, uint32_t r )
{
	int mode = (r & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_MODE_MASK) >> WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_MODE_SHIFT;

	char *mode_str = (mode == 0 ? "slave" : "phase monitor");

	int enabled = ( r & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_ENABLED) ? 1 : 0;
	int ready = ( r & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_LOCKED) ? 1 : 0;

	int phase = (r & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_PHASE_MASK) >> WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_PHASE_SHIFT;

	printf("AUX%d: mode %s enabled %d locked %d phase %d ps\n", index, mode_str, enabled, ready, phase );
}

static void print_aux_clock_status(void)
{
        unsigned v;

        v = board->readl(board, WDIAG_REG(WDIAG_AUX0_DETAIL_STAT));
	print_aux_clock_status_single(0, v);

        v = board->readl(board, WDIAG_REG(WDIAG_AUX1_DETAIL_STAT));
	print_aux_clock_status_single(1, v);

        v = board->readl(board, WDIAG_REG(WDIAG_AUX2_DETAIL_STAT));
	print_aux_clock_status_single(2, v);

        v = board->readl(board, WDIAG_REG(WDIAG_AUX3_DETAIL_STAT));
	print_aux_clock_status_single(3, v);
}

#define WDIAG_READ(REG) board->readl(board, WDIAG_REG(REG))

static int read_diags(unsigned reg_version)
{
	int res;

	res = lock_diag();
	if (res)
                return -1;

        printf("Diag registers layout version: %d\n", reg_version );
        print_servo_status(WDIAG_READ(WDIAG_SSTAT));
        print_port_status(WDIAG_READ(WDIAG_PSTAT));
        print_ptp_state(WDIAG_READ(WDIAG_PTPSTAT));
        print_aux_state(WDIAG_READ(WDIAG_ASTAT));
        print_tx_frame_count(WDIAG_READ(WDIAG_TXFCNT));
        print_rx_frame_count(WDIAG_READ(WDIAG_RXFCNT));
        if( reg_version >= 2 )
                print_rx_error_count(WDIAG_READ(WDIAG_RX_ERR_CNT));
        print_local_time(WDIAG_READ(WDIAG_SEC_MSB),
                         WDIAG_READ(WDIAG_SEC_LSB),
                         WDIAG_READ(WDIAG_NS));
        print_roundtrip_time(WDIAG_READ(WDIAG_MU_MSB),
                             WDIAG_READ(WDIAG_MU_LSB));
        print_master_slave_delay(WDIAG_READ(WDIAG_DMS_MSB),
                                 WDIAG_READ(WDIAG_DMS_LSB));
        print_link_asym(WDIAG_READ(WDIAG_ASYM));
        print_clock_offset(WDIAG_READ(WDIAG_CKO));
        print_phase_setpoint(WDIAG_READ(WDIAG_SETP));
        print_update_counter(WDIAG_READ(WDIAG_UCNT));
        print_board_temp(WDIAG_READ(WDIAG_TEMP));

        if (reg_version >= 2)
                print_aux_clock_status();

	unlock_diag();

	return 0;
}

static int do_wdiags(int argc, char *argv[])
{
	unsigned ver;

	if (board_open(&argc, argv) < 0)
		return 1;

	ver = board->readl(board, WDIAG_REG(VER));
	if (ver != 1 && ver != 2) {
		fprintf (stderr, "incorrect wdiag verion (read %08x)\n", ver);
		board->fini(board);
		return 1;
	}

        read_diags(ver);

	board->fini(board);

	return 0;
}

static void help_aux_logger(void)
{
	printf("usage: %s aux-logger\n", progname);
}

static int do_aux_logger(int argc, char *argv[])
{
	unsigned ver;
        unsigned timeout = 120;
        unsigned good_samples = 0;
	if (board_open(&argc, argv) < 0)
		return 1;

	ver = board->readl(board, WDIAG_REG(VER));
	if (ver != 1 && ver != 2) {
		fprintf (stderr, "incorrect wdiag verion (read %08x)\n", ver);
		board->fini(board);
		return 1;
	}

	while (1)
	{
                int res = lock_diag();
                if (res)
                        return -1;

		uint32_t aux0_stat = board->readl(board, WDIAG_REG(WDIAG_AUX0_DETAIL_STAT));

                if (aux0_stat & WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_LOCKED)
		{
			unsigned phase = aux0_stat & 0xffffff;
                        unsigned long long mu, dms;

                        mu = ((uint64_t)WDIAG_READ(WDIAG_MU_MSB) << 32)
                                | WDIAG_READ(WDIAG_MU_LSB);

                        dms = ((uint64_t)WDIAG_READ(WDIAG_DMS_MSB) << 32)
                                | WDIAG_READ(WDIAG_DMS_LSB);

			if(good_samples == 3 )
			{
				printf("[%d,%lld,%lld,%d,%d,%d]\n", phase,
                                       mu, dms,
                                       WDIAG_READ(WDIAG_ASYM),
                                       WDIAG_READ(WDIAG_CKO),
                                       WDIAG_READ(WDIAG_SETP));
				break;
			}

			good_samples++;
                }
                timeout--;
                if(!timeout)
                {
                        printf("Timeout!\n");
                        break;
                }

                unlock_diag();
		sleep(1);
	}

        unlock_diag();

	board->fini(board);

	return 0;
}

static const struct tool_base tool_help = {
        "help",
        "display list of commands (this help), or help for a command",
        do_help,
        NULL
};

static const struct tool_base tool_board = {
        "board",
        "display list of supported boards, or help for a board",
        do_board,
        NULL
};

static const struct tool_base tool_version = {
        "version",
        "display tool version",
        do_version,
        NULL
};

static const struct tool_base tool_load = {
        "load",
        "load wrpc firmware and restart",
        do_load,
        help_load
};

static const struct tool_base tool_vuart = {
        "vuart",
        "virtual uart, connect to wrpc cli",
        do_vuart,
        help_vuart
};

static const struct tool_base tool_info = {
        "info",
        "display wrpc info and check board",
        do_info,
        help_info
};

static const struct tool_base tool_spll_recorder = {
        "spll-recorder",
        "SoftPLL log recorder",
        do_spll_recorder,
        help_spll_recorder
};

static const struct tool_base tool_gdbserver = {
        "gdbserver",
        "risc-v gdb-sever",
        do_gdbserver,
        help_gdbserver
};

static const struct tool_base tool_wdiags = {
        "wdiags",
        "WR diags dumper",
        do_wdiags,
        help_wdiags
};

static const struct tool_base tool_aux_logger = {
        "aux-logger",
        "display wdiag AUX0 value for logging",
        do_aux_logger,
        help_aux_logger
};

static const struct tool_base *tools[] = {
	&tool_help,
	&tool_version,
        &tool_board,
	&tool_load,
	&tool_vuart,
	&tool_info,
	&tool_spll_recorder,
	&tool_gdbserver,
	&tool_wdiags,
        &tool_aux_logger,
	NULL
};

int main(int argc, char *argv[])
{
	const char *progbase;
	const char *toolname;
	const struct tool_base *tool;

	/* Extract tool from argv[0].  */
	progname = argv[0];
	progbase = get_basename(progname);
	if (argc > 1 && argv[1][0] != '-') {
		/* Extract command. */
		toolname = argv[1];

		remove_arg1(&argc, argv);
	}
	else if (argc > 1 && strcmp(argv[1], "--version") == 0) {
		do_version(0, NULL);
		return 0;
	}
	else if (memcmp(progbase, "wrpc-", 5) == 0) {
		toolname = progbase + 5;
	}
	else {
		fprintf (stderr, "no tool name, try %s help\n", progname);
		return 1;
	}

	/* Find tool.  */
	for (unsigned i = 0; (tool = tools[i]); i++) {
		if (strcmp (tool->name, toolname) == 0)
			break;
	}
	if (tool == NULL) {
		fprintf(stderr, "tool '%s' is unknown, try %s help\n",
			toolname, progname);
		return 1;
	}

	if (argc > 1)
		if (strcmp (argv[1], "-h") == 0
		    || strcmp (argv[1], "--help") == 0) {
			tool->help();
			return 0;
		}

	return tool->run(argc, argv);
}
