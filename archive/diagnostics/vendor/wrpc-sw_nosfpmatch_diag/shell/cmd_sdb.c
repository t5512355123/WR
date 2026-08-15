/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <string.h>

#include "pp-printf.h"
#include "shell.h"
#include "dev/syscon.h"
#include "storage.h"
#include "dev/flash.h"
#include "libsdbfs.h"
#include "util.h"
#include "wrc.h"

/*
 * args[1] - where to write sdbfs image (0 - Flash, 1 - I2C EEPROM,
 *		2 - 1Wire EEPROM)
 * args[2] - base address for sdbfs image in Flash/EEPROM
 * args[3] - i2c address of EEPROM or blocksize of Flash
 */

static const char * const sdb_cmds[] =
{
	 [0] = "format",
	 [1] = "fs",
	 [2] = "fse",
	 [3] = "ls",
#if CONFIG_CMD_SDB_RDUMP
	 [4] = "rdump",
#endif
};

#if CONFIG_CMD_SDB_RDUMP
static void cmd_sdb_rdump(unsigned off)
{
	struct storage_device *dev = wrc_sdbfs.dev;
	unsigned char buf[256];
	unsigned i, j;
	int res;

	if (dev == NULL)
		return;
	res = dev->rwops->read(dev->priv, off, buf, sizeof(buf));
	if (res != sizeof(buf)) {
		pp_printf("read error: %d\n", res);
		return;
	}

	for (i = 0; i < sizeof(buf); i += 16) {
		pp_printf("%08x:", off + i);
		for (j = 0; j < 16; j++)
			pp_printf(" %02x", buf[i + j]);
		pp_printf ("  ");
		for (j = 0; j < 16; j++) {
			unsigned c = buf[i + j];
			if (c < 32 || c > 127)
				c = '.';
			pp_printf("%c", c);
		}
		pp_printf("\n");
	}
}
#endif

static int cmd_sdb(const char *args[])
{
	int icmd;

	icmd = sub_cmd(sdb_cmds, ARRAY_SIZE(sdb_cmds), args);

	switch(icmd) {
	case 0:
	case 1:
	{
		pp_printf("Formatting using ");

		if (!args[1]) {
			pp_printf("default location\n");
			storage_sdbfs_format( &wrc_storage_dev, 0, 0 );
		} else {
			uint32_t base = atoi(args[1]);
			pp_printf("location 0x%X\n", (unsigned int) base);
			storage_sdbfs_format( &wrc_storage_dev, base, 1 );
		}
		return 0;
	}
	case 2:
	{
		pp_printf("Erasing using ");
		if (!args[1]) {
			pp_printf("default location\n");
			storage_sdbfs_erase( &wrc_storage_dev, 0, 0 );
		} else {
			uint32_t base = atoi(args[1]);
			pp_printf("location 0x%X\n", (unsigned int) base);
			storage_sdbfs_erase( &wrc_storage_dev, base, 1 );
		}
		return 0;
	}
	case 3:
		storage_sdbfs_list();
		return 0;
#if CONFIG_CMD_SDB_RDUMP
	case 4:
	{
		int addr;
		if (args[1])
			fromhex(args[1], &addr);
		else
			addr = 0;
		cmd_sdb_rdump(addr);
		return 0;
	}
#endif
	default:
		return icmd;
	}
}

DEFINE_WRC_COMMAND(sdb) = {
	.name = "sdb",
	.exec = cmd_sdb,
};
