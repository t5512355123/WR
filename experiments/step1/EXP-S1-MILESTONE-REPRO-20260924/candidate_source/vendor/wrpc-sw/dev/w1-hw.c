/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2013 CERN (www.cern.ch)
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <string.h>
#include <dev/w1.h>
#include <board.h>
#include <hw/sockit_owm_regs.h>

#define ONEWIRE_PORT 0

static inline uint32_t __wait_cycle(void)
{
	uint32_t reg;

	while ((reg = IORD_SOCKIT_OWM_CTL(BASE_ONEWIRE))
	       & SOCKIT_OWM_CTL_CYC_MSK)
		;
	return reg;
}

int w1_reset(struct w1_bus *bus)
{
	int portnum = ONEWIRE_PORT;
	uint32_t reg;

	IOWR_SOCKIT_OWM_CTL(BASE_ONEWIRE, (portnum << SOCKIT_OWM_CTL_SEL_OFST)
			    | (SOCKIT_OWM_CTL_CYC_MSK)
			    | (SOCKIT_OWM_CTL_RST_MSK));
	reg = __wait_cycle();
	/* return presence-detect pulse (1 if true) */
	return (reg & SOCKIT_OWM_CTL_DAT_MSK) ? 0 : 1;
}

int w1_read_bit(struct w1_bus *bus)
{
	int portnum = ONEWIRE_PORT;
	uint32_t reg;

	IOWR_SOCKIT_OWM_CTL(BASE_ONEWIRE, (portnum << SOCKIT_OWM_CTL_SEL_OFST)
			    | (SOCKIT_OWM_CTL_CYC_MSK)
			    | (SOCKIT_OWM_CTL_DAT_MSK));
	reg = __wait_cycle();
	return (reg & SOCKIT_OWM_CTL_DAT_MSK) ? 1 : 0;
}

void w1_write_bit(struct w1_bus *bus, int bit)
{
	int portnum = ONEWIRE_PORT;

	IOWR_SOCKIT_OWM_CTL(BASE_ONEWIRE, (portnum << SOCKIT_OWM_CTL_SEL_OFST)
			    | (SOCKIT_OWM_CTL_CYC_MSK)
			    | (bit ? SOCKIT_OWM_CTL_DAT_MSK : 0));
	__wait_cycle();
}

/* Init from sockitowm code */
#define CLK_DIV_NOR (CPU_CLOCK / 200000 - 1)	/* normal mode */
#define CLK_DIV_OVD (CPU_CLOCK / 1000000 - 1)	/* overdrive mode (not used) */
void w1_init(void)
{
	IOWR_SOCKIT_OWM_CDR(BASE_ONEWIRE,
			    ((CLK_DIV_NOR & SOCKIT_OWM_CDR_N_MSK) |
			     ((CLK_DIV_OVD << SOCKIT_OWM_CDR_O_OFST) &
			      SOCKIT_OWM_CDR_O_MSK)));
}
