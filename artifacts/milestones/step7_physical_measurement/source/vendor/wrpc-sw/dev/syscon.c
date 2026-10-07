/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Grzegorz Daniluk <grzegorz.daniluk@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#include <errno.h>
#include <string.h>
#include "endianness.h"
#include "dev/syscon.h"
#include "pp-printf.h"
#include "dev/gpio.h"
#include "dev/bb_i2c.h"
#include "hw/wrc_syscon_regs.h"

#define SYSCON  ((volatile struct SYSC_WB *)BASE_SYSCON)

static void sysc_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
}

static void sysc_gpio_set_out(const struct gpio_pin *pin, int value)
{
	if(value)
		SYSCON->GPSR = ( 1<< pin->pin);
	else
		SYSCON->GPCR = ( 1<< pin->pin);
}

static int sysc_gpio_read_pin(const struct gpio_pin *pin)
{
	return (SYSCON->GPSR & (1<<pin->pin)) ? 1 : 0;
}

static const struct gpio_device syscon_gpio = {
	NULL,
	sysc_gpio_set_dir,
	sysc_gpio_set_out,
	sysc_gpio_read_pin
};

// fixme: use indices for GPIO pins in the WB file, not masks
const struct gpio_pin pin_sysc_fmc_scl = { &syscon_gpio, 2 };
const struct gpio_pin pin_sysc_fmc_sda = { &syscon_gpio, 3 };
const struct gpio_pin pin_sysc_net_rst = { &syscon_gpio, 4 };
const struct gpio_pin pin_sysc_btn1 = { &syscon_gpio, 5 };
const struct gpio_pin pin_sysc_btn2 = { &syscon_gpio, 6 };
const struct gpio_pin pin_sysc_sfp1_det = { &syscon_gpio, 7 };
const struct gpio_pin pin_sysc_sfp1_scl = { &syscon_gpio, 8 };
const struct gpio_pin pin_sysc_sfp1_sda = { &syscon_gpio, 9 };
const struct gpio_pin pin_sysc_spi_sclk = { &syscon_gpio, 10 };
const struct gpio_pin pin_sysc_spi_ncs = { &syscon_gpio, 11 };
const struct gpio_pin pin_sysc_spi_mosi = { &syscon_gpio, 12 };
const struct gpio_pin pin_sysc_spi_miso = { &syscon_gpio, 13 };

#define FMC_I2C_DELAY 15
#define SFP_I2C_DELAY 300

const struct i2c_bus dev_i2c_fmc = {
	(struct gpio_pin*) &pin_sysc_fmc_scl,
	(struct gpio_pin*) &pin_sysc_fmc_sda,
	FMC_I2C_DELAY
};

const struct i2c_bus dev_i2c_sfp1 = {
	(struct gpio_pin*) &pin_sysc_sfp1_scl,
	(struct gpio_pin*) &pin_sysc_sfp1_sda,
	SFP_I2C_DELAY
};


int sysc_get_memsize(void)
{
	return (SYSC_HWFR_MEMSIZE_R(SYSCON->HWFR) + 1) * 16;
}

unsigned sysc_get_hwbuild_date(void)
{
	return SYSCON->HWBLD;
}

/****************************
 *       BOARD NAME
 ***************************/
void get_hw_name(char *str)
{
	uint32_t val;

	val = ntohl(SYSCON->HWIR);
	memcpy(str, &val, HW_NAME_LENGTH-1);
}

/****************************
 *       Flash info
 ***************************/
void get_storage_info(int *memtype, uint32_t *sdbfs_baddr, uint32_t *blocksize)
{
	/* convert sector size from KB to bytes */
	*blocksize = SYSC_HWFR_STORAGE_SEC_R(SYSCON->HWFR) * 1024;
	*sdbfs_baddr = SYSCON->SDBFS;
	*memtype = SYSC_HWFR_STORAGE_TYPE_R(SYSCON->HWFR);
}

/****************************
 *        TIMER
 ***************************/
void timer_init(uint32_t enable)
{
	if (enable)
		SYSCON->TCR |= SYSC_TCR_ENABLE;
	else
		SYSCON->TCR &= ~SYSC_TCR_ENABLE;
}

uint32_t timer_get_tics(void)
{
	return SYSCON->TVR;
}

void timer_delay(uint32_t tics)
{
	uint32_t t_end;

	/*
	timer_init(1);
	*/

	t_end = timer_get_tics() + tics;
	while (time_before(timer_get_tics(), t_end))
	       ;
}

static int diag_rw_words, diag_ro_words;

/****************************
 *        AUX Diagnostics
 ***************************/
void diag_read_info(uint32_t *id, uint32_t *ver, uint32_t *nrw, uint32_t *nro)
{
	diag_rw_words = SYSC_DIAG_NW_RW_R(SYSCON->DIAG_NW);
	diag_ro_words = SYSC_DIAG_NW_RO_R(SYSCON->DIAG_NW);

	if (id)
		*id = SYSC_DIAG_INFO_ID_R(SYSCON->DIAG_INFO);
	if (ver)
		*ver = SYSC_DIAG_INFO_VER_R(SYSCON->DIAG_INFO);
	if (nrw)
		*nrw = diag_rw_words;
	if (nro)
		*nro = diag_ro_words;
}

int diag_read_word(uint32_t adr, int bank, uint32_t *val)
{
	if (!val)
		return -EINVAL;

	if (diag_rw_words == 0) {
		pp_printf("fetching diag_rw_words\n");
		diag_rw_words = SYSC_DIAG_NW_RW_R(SYSCON->DIAG_NW);
	}
	if (diag_ro_words == 0) {
		pp_printf("fetching diag_ro_words\n");
		diag_ro_words = SYSC_DIAG_NW_RO_R(SYSCON->DIAG_NW);
	}

	if ((bank == DIAG_RW_BANK && adr >= diag_rw_words) ||
		(bank == DIAG_RO_BANK && adr >= diag_ro_words)) {
		*val = 0;
		return -EINVAL;
	}

	if (bank == DIAG_RO_BANK)
		adr += diag_rw_words;

	SYSCON->DIAG_CR = SYSC_DIAG_CR_ADR_W(adr);
	*val = SYSCON->DIAG_DAT;

	return 0;
}

int diag_write_word(uint32_t adr, uint32_t val)
{
	if (adr >= diag_rw_words)
		return -EINVAL;

	SYSCON->DIAG_DAT = val;
	SYSCON->DIAG_CR = SYSC_DIAG_CR_RW | SYSC_DIAG_CR_ADR_W(adr);

	return 0;
}

void net_rst(void)
{
	SYSCON->GPSR |= SYSC_GPSR_NET_RST;
}
