/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#ifndef __IRQ_H
#define __IRQ_H

#ifdef unix
  static inline void clear_irq(void) {}

#elif defined(CONFIG_ARCH_RISCV)
static inline void clear_irq(void) {
    unsigned long t;
    /* AW: needed? */
    asm volatile ("csrrc %0, mip, %1" : "=r"(t) : "r"(1 << 11));
}

#else
static inline void clear_irq(void)
{
	unsigned int val = 1;
	asm volatile ("wcsr ip, %0"::"r" (val));
}

#endif

void disable_irq(void);
void enable_irq(void);
void spll_irq_entry(void);

#endif
