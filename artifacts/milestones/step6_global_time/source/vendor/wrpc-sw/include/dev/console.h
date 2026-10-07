/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012-2019 CERN (www.cern.ch)
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __CONSOLE_H
#define __CONSOLE_H

#include <stdint.h>

#define CONSOLE_FLAGS_MODE_BINARY (1<<0)
#define CONSOLE_FLAGS_MODE_TTY    (1<<1)
#define CONSOLE_FLAGS_INSERT_CRLF (1<<2)


struct console_device {
    int (*get_char)( struct console_device *dev );
    int (*put_string)( struct console_device *dev, const char *str );
    void *priv;
    int flags;
};

void console_init(void);
int console_getc(void);
void console_register_device( struct console_device *dev );


#ifdef CONFIG_IPMI_CONSOLE
int console_ipmi_process_request(struct console_device* dev,  uint8_t *req, int size, uint8_t *rsp, int rsp_size );
void console_ipmi_init( void );
#endif

#ifdef CONFIG_NETCONSOLE
void console_netconsole_init(void);
#endif

#ifdef CONFIG_PUTS_SYSLOG
void console_syslog_init(void);
#endif

#endif

