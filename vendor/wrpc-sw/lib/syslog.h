/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __SYSLOG_H
#define __SYSLOG_H

#ifdef CONFIG_SYSLOG
#  define HAS_SYSLOG 1
#else
#  define HAS_SYSLOG 0
#endif

#ifdef CONFIG_PUTS_SYSLOG
#define HAS_PUTS_SYSLOG 1
#else
#define HAS_PUTS_SYSLOG 0
#endif

void syslog_init(void);
int syslog_poll(void);
void syslog_report(const char *buf);
int syslog_puts(const char *s); /* for syslog console */

#endif
