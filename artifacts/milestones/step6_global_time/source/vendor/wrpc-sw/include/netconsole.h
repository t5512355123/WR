/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __NETCONSOLE_H__
#define __NETCONSOLE_H__

#ifdef CONFIG_NETCONSOLE
#define HAS_NETCONSOLE 1
#else
#define HAS_NETCONSOLE 0
#endif

#define NETCONSOLE_ENABLED 1
#define NETCONSOLE_DISABLED 2
#define NETCONSOLE_WAIT 3

#define NETCONSOLE_PORT 55

extern struct wr_sockaddr netconsole_sock_addr;
extern int netconsole_status;
extern struct wr_udp_addr netconsole_udp_addr;

void netconsole_init(void);
int netconsole_poll(void);

int netconsole_read_byte(void);
int netconsole_write_string(const char *s);


#endif /* __NETCONSOLE_H__ */
