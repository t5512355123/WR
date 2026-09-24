/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011d CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 * Author: Alessandro Rubini <rubini@gnudd.com>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

/*
 * Trivial pll programmer using an spi controller.
 * PLL is AD9516, SPI is opencores
 */
#include <stdint.h>
#include "wrc.h"

#include "board.h"
#include "dev/syscon.h"
#include "dev/gpio.h"
#include "gpio-wrs.h"
#include "hw/rawmem.h"

#include "rt_ipc.h"

#ifndef ARRAY_SIZE
#define ARRAY_SIZE(a) (sizeof(a)/sizeof(a[0]))
#endif

struct ad9516_reg {
	uint16_t reg;
	uint8_t val;
};

#include "ad9516_config.h"

/*
 * SPI stuff, used by later code
 */

#define SPI_REG_RX0	0
#define SPI_REG_TX0	0
#define SPI_REG_RX1	4
#define SPI_REG_TX1	4
#define SPI_REG_RX2	8
#define SPI_REG_TX2	8
#define SPI_REG_RX3	12
#define SPI_REG_TX3	12

#define SPI_REG_CTRL	16
#define SPI_REG_DIVIDER	20
#define SPI_REG_SS	24

#define SPI_CTRL_ASS		(1<<13)
#define SPI_CTRL_IE		(1<<12)
#define SPI_CTRL_LSB		(1<<11)
#define SPI_CTRL_TXNEG		(1<<10)
#define SPI_CTRL_RXNEG		(1<<9)
#define SPI_CTRL_GO_BSY		(1<<8)
#define SPI_CTRL_CHAR_LEN(x)	((x) & 0x7f)

#define CS_PLL	0 /* AD9516 on SPI CS0 */

static int oc_spi_init(void *base_addr)
{
	writel(100, base_addr + SPI_REG_DIVIDER);
	return 0;
}

static int oc_spi_txrx(void *base, int ss, int nbits, uint32_t in, uint32_t *out)
{
	uint32_t rval;

	if (!out)
		out = &rval;

	writel(SPI_CTRL_ASS | SPI_CTRL_CHAR_LEN(nbits)
		     | SPI_CTRL_TXNEG,
		     base + SPI_REG_CTRL);

	writel(in, base + SPI_REG_TX0);
	writel((1 << ss), base + SPI_REG_SS);
	writel(SPI_CTRL_ASS | SPI_CTRL_CHAR_LEN(nbits)
		     | SPI_CTRL_TXNEG | SPI_CTRL_GO_BSY,
		     base + SPI_REG_CTRL);

	while(readl(base + SPI_REG_CTRL) & SPI_CTRL_GO_BSY)
		;
	*out = readl(base + SPI_REG_RX0);
	return 0;
}

/*
 * AD9516 stuff, using SPI, used by later code.
 * "reg" is 12 bits, "val" is 8 bits, but both are better used as int
 */

static void ad9516_write_reg(void *base, int reg, int val)
{
	oc_spi_txrx(base, CS_PLL, 24, (reg << 8) | val, NULL);
}

static int ad9516_read_reg(void *base, int reg)
{
	uint32_t rval;
	oc_spi_txrx(base, CS_PLL, 24, (reg << 8) | (1 << 23), &rval);
	return rval & 0xff;
}



static void ad9516_load_regset(void *base, const struct ad9516_reg *regs, int n_regs, int commit)
{
	int i;
	for(i=0; i<n_regs; i++)
		ad9516_write_reg(base, regs[i].reg, regs[i].val);
		
	if(commit)
		ad9516_write_reg(base, 0x232, 1);
}


static void ad9516_wait_lock(void *base)
{
	while ((ad9516_read_reg(base,  0x1f) & 1) == 0);
}

#define SECONDARY_DIVIDER 0x100

static int ad9516_set_output_divider(void *spi_base, int output, int ratio, int phase_offset)
{
	uint8_t lcycles = (ratio/2) - 1;
	uint8_t hcycles = (ratio - (ratio / 2)) - 1;
	int secondary = (output & SECONDARY_DIVIDER) ? 1 : 0;
	output &= 0xf;

	if(output >= 0 && output < 6) /* LVPECL outputs */
	{
		uint16_t base = (output / 2) * 0x3 + 0x190;

		if(ratio == 1)  /* bypass the divider */
		{
			uint8_t div_ctl = ad9516_read_reg(spi_base, base + 1);
			ad9516_write_reg(spi_base, base + 1, div_ctl | (1<<7) | (phase_offset & 0xf));
		} else {
			uint8_t div_ctl = ad9516_read_reg(spi_base, base + 1);
			ad9516_write_reg(spi_base, base + 1, (div_ctl & (~(1<<7))) | (phase_offset & 0xf));  /* disable bypass bit */
			ad9516_write_reg(spi_base, base, (lcycles << 4) | hcycles);
		}
	} else { /* LVDS/CMOS outputs */
			
		uint16_t base = ((output - 6) / 2) * 0x5 + 0x199;

		pp_printf("Output [divider %d]: %d ratio: %d base %x lc %d hc %d\n", secondary, output, ratio, base, lcycles ,hcycles);

		if(!secondary)
		{
			if(ratio == 1)  /* bypass the divider 1 */
				ad9516_write_reg(spi_base, base + 3, ad9516_read_reg(spi_base, base + 3) | 0x10);
			else {
				ad9516_write_reg(spi_base, base, (lcycles << 4) | hcycles);
				ad9516_write_reg(spi_base, base + 1, phase_offset & 0xf);
			}
		} else {
			if(ratio == 1)  /* bypass the divider 2 */
				ad9516_write_reg(spi_base, base + 3, ad9516_read_reg(spi_base, base + 3) | 0x20);
			else {
				ad9516_write_reg(spi_base, base + 2, (lcycles << 4) | hcycles);
//				ad9516_write_reg(base + 1, phase_offset & 0xf);
				
		}
		}		
	}

	/* update */
	ad9516_write_reg(spi_base, 0x232, 0x0);
	ad9516_write_reg(spi_base, 0x232, 0x1);
	ad9516_write_reg(spi_base, 0x232, 0x0);
	return 0;
}

static int ad9516_set_vco_divider(void *spi_base, int ratio) /* Sets the VCO divider (2..6) or 0 to enable static output */
{
	if(ratio == 0)
		ad9516_write_reg(spi_base, 0x1e0, 0x5); /* static mode */
	else
		ad9516_write_reg(spi_base, 0x1e0, (ratio-2));
	ad9516_write_reg(spi_base, 0x232, 0x1);
	ad9516_write_reg(spi_base, 0x232, 0x0);

	return 0;
}

static void ad9516_sync_outputs(void *spi_base)
{
	/* VCO divider: static mode */
	ad9516_write_reg(spi_base, 0x1E0, 0x7);
	ad9516_write_reg(spi_base, 0x232, 0x1);

	/* Sync the outputs when they're inactive to avoid +-1 cycle uncertainity */
	ad9516_write_reg(spi_base, 0x230, 1);
	ad9516_write_reg(spi_base, 0x232, 1);
	ad9516_write_reg(spi_base, 0x230, 0);
	ad9516_write_reg(spi_base, 0x232, 1);
	ad9516_write_reg(spi_base, 0x232, 0x0);

}

int ad9516_init(int scb_version, int ljd_present)
{
	pp_printf("Initializing AD9516 PLL...\n");

	oc_spi_init((void *)BASE_SPI);
	
	void *spi_base = (void *)BASE_SPI;

	gen_gpio_out(&gpio_pin_sys_clk_sel, 0); /* switch to the standby reference clock, since the PLL is off after reset */

	/* reset the PLL */
	gen_gpio_out(&gpio_pin_pll_reset_n, 0);
	timer_delay(10);
	gen_gpio_out(&gpio_pin_pll_reset_n, 1);
	timer_delay(10);
	
	/* Use unidirectional SPI mode */
	ad9516_write_reg(spi_base, 0x000, 0x99);

	/* Check the presence of the chip */
	if (ad9516_read_reg(spi_base, 0x3) != 0xc3) {
		pp_printf("Error: AD9516 PLL not responding.\n");
		return -1;
	}

	if( scb_version >= 34)	//New SCB v3.4. 10MHz Output.
		ad9516_load_regset(spi_base, ad9516_base_config_34, ARRAY_SIZE(ad9516_base_config_34), 0);
	else 				//Old one
		ad9516_load_regset(spi_base, ad9516_base_config_33, ARRAY_SIZE(ad9516_base_config_33), 0);

	/* Set R divider value depending on Low-Jitter Daughterboard presence */
	if (ljd_present)
		ad9516_load_regset(spi_base, ad9516_ref_ljd, ARRAY_SIZE(ad9516_ref_ljd), 1);
	else
		ad9516_load_regset(spi_base, ad9516_ref_tcxo, ARRAY_SIZE(ad9516_ref_tcxo), 1);
	ad9516_wait_lock(spi_base);

	ad9516_sync_outputs(spi_base);

	if( scb_version >= 34) {	//New SCB v3.4. 10MHz Output.

		ad9516_set_output_divider(spi_base, 2, 4, 0);  	// OUT2. 187.5 MHz. - not anymore
		ad9516_set_output_divider(spi_base, 3, 4, 0);  	// OUT3. 187.5 MHz. - not anymore

		ad9516_set_output_divider(spi_base, 4, 1, 0);  	// OUT4. 500 MHz.

		/*The following PLL outputs have been configured through the ad9516_base_config_34 register,
		 * so it doesn't need to replicate the configuration:
		 *
		 * Output 6 => 62.5 MHz
		 * Output 7	=> 62.5 MHz
		 * Output 8	=> 10 MHz
		 * Output 9	=> 10 MHz
		 */

	} else {	//Old one

		ad9516_set_output_divider(spi_base, 9, 4, 0);  /* AUX/SWCore = 187.5 MHz */ //not needed anymore
		ad9516_set_output_divider(spi_base, 7, 8, 0); /* REF = 62.5 MHz */
		ad9516_set_output_divider(spi_base, 4, 8, 0);  /* GTX = 62.5 MHz */
	}

	ad9516_sync_outputs(spi_base);
	ad9516_set_vco_divider(spi_base, 3);
	
	pp_printf("AD9516 locked.\n");

	gen_gpio_out(&gpio_pin_sys_clk_sel, 1); /* switch the system clock to the PLL reference */
	gen_gpio_out(&gpio_pin_periph_reset_n, 0); /* reset all peripherals which use AD9516-provided clocks */
	gen_gpio_out(&gpio_pin_periph_reset_n, 1);

	return 0;
}

int ljd_ad9516_init (void) {
 	pp_printf("Initializing Low-Jitter Daughterboard AD9516 PLL...\n");
	oc_spi_init((void *)BASE_SPI_LJD_BOARD);
	void *spi_base = (void *)BASE_SPI_LJD_BOARD;

	/* Use unidirectional SPI mode */
	ad9516_write_reg((void *)spi_base, 0x000, 0x99);

	/* Check the presence of the chip */
	if (ad9516_read_reg((void *)spi_base, 0x3) != 0xc3) {
		pp_printf("Error: Low-Jitter Daughterboard AD9516 PLL not responding.\n");
		return -1;
	}
	ad9516_write_reg(spi_base, 0x018, 0x0); // reset VCO calibration
	ad9516_write_reg(spi_base, 0x232, 0x0);
	ad9516_write_reg(spi_base, 0x232, 0x1);
	ad9516_write_reg(spi_base, 0x232, 0x0);
	
  	ad9516_set_vco_divider(spi_base, 3);
	ad9516_load_regset(spi_base, ad9516_ljd_base_config, ARRAY_SIZE(ad9516_ljd_base_config), 1);
	 
	ad9516_set_output_divider(spi_base, 6, 8, 0);  	// OUT6. 62.5MHz
	ad9516_set_output_divider(spi_base, 8, 20, 0);  // OUT6. 62.5MHz

	return 0;
}


int rts_debug_command(int command, int value)
{
	switch(command)
	{
		case RTS_DEBUG_ENABLE_SERDES_CLOCKS:
			if(value)
			{
				ad9516_write_reg((void *)BASE_SPI, 0xf4, 0x08); // OUT4 enabled
				ad9516_write_reg((void *)BASE_SPI, 0x232, 0x0);
				ad9516_write_reg((void *)BASE_SPI, 0x232, 0x1);
			} else {
				ad9516_write_reg((void *)BASE_SPI, 0xf4, 0x0a); // OUT4 power-down, no serdes clock
				ad9516_write_reg((void *)BASE_SPI, 0x232, 0x0);
				ad9516_write_reg((void *)BASE_SPI, 0x232, 0x1);
			}
			break;
	}
	return 0;
}
