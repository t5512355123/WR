/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2020 CERN (www.cern.ch)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <stdio.h>
#include <stdint.h>
#include <errno.h>

#include "pp-printf.h"
#include "board.h"
#include "dev/simple_uart.h"
#include "dev/console.h"
#include "lib/syslog.h"
#include "netconsole.h"

#ifdef CONFIG_NETCONSOLE

static struct console_device console_netconsole_dev;

static int con_netconsole_getc(struct console_device* dev)
{
	return netconsole_read_byte();
}

static int con_netconsole_put_string(struct console_device* dev, const char *s)
{
	return netconsole_write_string(s);
}

void console_netconsole_init(void)
{
	console_netconsole_dev.get_char = con_netconsole_getc;
	console_netconsole_dev.put_string = con_netconsole_put_string;
	console_register_device( &console_netconsole_dev );
}

#endif

#ifdef CONFIG_PUTS_SYSLOG

static struct console_device console_syslog_dev;

static int con_syslog_put_string(struct console_device* dev, const char *s)
{
	return syslog_puts(s);
}


void console_syslog_init(void)
{
	/* no get_char for syslog! */
	console_syslog_dev.put_string = con_syslog_put_string;
	console_register_device(&console_syslog_dev);
}

#endif
