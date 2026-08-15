/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __FAKETEMP_H
#define __FAKETEMP_H

#ifdef CONFIG_TEMP_FAKE
#define HAS_TEMP_FAKE 1
#else
#define HAS_TEMP_FAKE 0
#endif

void temp_faketemp_init(void);

#endif /* __FAKETEMP_H */
