/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __W1TEMP_H
#define __W1TEMP_H

#ifdef CONFIG_W1_TEMP
#define HAS_W1_TEMP 1
#else
#define HAS_W1_TEMP 0
#endif

void temp_w1_init(void);

#endif /* __W1TEMP_H */
