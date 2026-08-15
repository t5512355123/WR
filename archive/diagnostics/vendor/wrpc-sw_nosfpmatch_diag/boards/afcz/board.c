/* We need the common board.h */
#include "../../include/board.h"

#include "wrc-debug.h"
#include "dev/syscon.h"
#include "dev/i2c.h"
#include "dev/gpio.h"
#include "dev/bb_i2c.h"
#include "dev/clock_monitor.h"
#include "dev/i2c_eeprom.h"
#include "dev/syscon.h"
#include "dev/bb_spi.h"
#include "dev/spi_flash.h"
#include "dev/endpoint.h"
#include "dev/netif.h"
#include "dev/minic.h"
#include "softpll_ng.h"

#include "hw/si570_if_wb.h"

#include "storage.h"
#include "wrc.h"

struct wr_si57x_interface_device
{
	void *base_addr;
	uint8_t i2c_addr;
	struct gpio_pin pin_scl;
	struct gpio_pin pin_sda;
	struct gpio_device gpio_i2c;
	struct i2c_bus master;
	int n1, hsdiv;
	uint64_t rfreq;
};

struct idt8v_clock_mux_device {
	struct i2c_bus *bus;
	uint8_t i2c_addr;
	uint8_t regs[16];
};

#define SI57X_PIN_SCL 0
#define SI57X_PIN_SDA 1

#define SI57X_I2C_ADDR 0x55
#define IDT8V_I2C_ADDR 0x58

struct pca9554_gpio_device
{
	struct i2c_bus *bus;
	uint8_t i2c_addr;
	struct gpio_device gpio;
};


static struct {
	struct gpio_device gpio_aux;
	struct wr_si57x_interface_device si57x;
	struct wb_clock_monitor_device clk_mon;
#if defined(CONFIG_TARGET_AFCZ_V1)
	struct idt8v_clock_mux_device clk_mux;
	struct pca9554_gpio_device gpio_rtm_main;
	struct pca9554_gpio_device gpio_rtm_sfp;
#endif
	struct i2c_eeprom_device mac_eeprom;
	// 2nd endpoint for the B-Train
	struct wr_endpoint_device ep_btrain;
} board;

#if defined(CONFIG_TARGET_AFCZ_V1)

static void idt8v_read_regs( struct idt8v_clock_mux_device*dev )
{
	int i;
	bb_i2c_start( dev->bus );
	bb_i2c_put_byte( dev->bus, (dev->i2c_addr << 1) | 1 );
	for( i = 0; i < 16; i++ )
		bb_i2c_get_byte( dev->bus, &dev->regs[i], i == 15 ? 1 : 0 );
	bb_i2c_stop( dev->bus );
}

static void idt8v_commit_configuration( struct idt8v_clock_mux_device*dev )
{
	int i;
	bb_i2c_start( dev->bus );
	bb_i2c_put_byte( dev->bus, (dev->i2c_addr << 1) );
	for( i = 0; i < 16; i++ )
		bb_i2c_put_byte( dev->bus, dev->regs[i] );
	bb_i2c_stop( dev->bus );
}


static void idt8v_clock_mux_init ( struct idt8v_clock_mux_device*dev, struct i2c_bus* bus, uint8_t i2c_addr )
{
	dev->bus = bus;
	dev->i2c_addr = i2c_addr;

	idt8v_read_regs( dev );
}



static void idt8v_configure_io ( struct idt8v_clock_mux_device*dev, int io_index, int is_input, int term_en, int output_sel )
{
	uint8_t r = 0;

	if( is_input )
	{
		r = term_en ? (1<<6) : 0;
	}
	else
	{
		r = (1 << 7) | output_sel;
	}

	dev->regs[ io_index ] = r;
}
#endif



static void si57x_gpio_out(const struct gpio_pin *pin, int value)
{
	struct wr_si57x_interface_device* dev = ( struct wr_si57x_interface_device* ) pin->device->priv;

	

	uint32_t mask = (pin->pin == SI57X_PIN_SCL ? SI570_GPCR_SCL : SI570_GPCR_SDA );
	uint32_t reg = (value ? SI570_REG_GPSR : SI570_REG_GPCR );


	writel( mask, dev->base_addr + reg );
}


static void si57x_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
	si57x_gpio_out(pin, !dir);
}


static int si57x_gpio_in(const struct gpio_pin *pin)
{
	struct wr_si57x_interface_device* dev = ( struct wr_si57x_interface_device* ) pin->device->priv;

	uint32_t gpsr = readl( dev->base_addr + SI570_REG_GPSR );

	if ( pin->pin == SI57X_PIN_SCL )
		return (gpsr & SI570_GPSR_SCL ? 1 : 0);
	else
		return (gpsr & SI570_GPSR_SDA ? 1 : 0);
}

#if defined(CONFIG_TARGET_AFCZ_V1)
static void tca9548_select_channels( struct i2c_bus *bus, uint8_t tca_address, uint8_t channel_mask )
{
	bb_i2c_start( bus );
	bb_i2c_put_byte( bus, tca_address << 1 );
	bb_i2c_put_byte( bus, channel_mask );
	bb_i2c_stop( bus );
}
#endif

static void si57x_read( struct wr_si57x_interface_device *dev, uint8_t addr, uint8_t *data, int count )
{
	int i;

	bb_i2c_start( &dev->master );
	bb_i2c_put_byte( &dev->master, dev->i2c_addr << 1 );
	bb_i2c_put_byte( &dev->master, addr );
	bb_i2c_repeat_start( &dev->master );
	bb_i2c_put_byte( &dev->master, (dev->i2c_addr << 1) | 1 );

	for(i = 0; i < count; i ++)
		bb_i2c_get_byte( &dev->master, &data[i], i == (count - 1) ? 1 : 0 );

	bb_i2c_stop( &dev->master );
}


static void si57x_write( struct wr_si57x_interface_device *dev, uint8_t addr, uint8_t *data, int count )
{
	int i;

	bb_i2c_start( &dev->master );
	bb_i2c_put_byte( &dev->master, dev->i2c_addr << 1 );
	bb_i2c_put_byte( &dev->master, addr );
	
	for(i = 0; i < count; i ++)
	{
		bb_i2c_put_byte( &dev->master, data[i] );
	}

	bb_i2c_stop( &dev->master );
}

static void si57x_get_xtal_frequency( struct wr_si57x_interface_device *dev, uint32_t* freq_hz )
{
	uint8_t regs[16];

	si57x_read( &board.si57x, 7, regs, 9 ); // R7... R15

	uint64_t rfreq = ( (uint64_t) regs[12-7] ) | // R12
					 ( ( (uint64_t) regs[11-7]) << 8 ) | // R11
					 ( ( (uint64_t) regs[10-7]) << 16 ) | // R10
					 ( ( (uint64_t) regs[9-7]) << 24 ) | // R9
					 ( ( (uint64_t) regs[8-7] & 0x3f) << 32 ); // R8

	uint64_t n1 = ( ( (regs[0] & 0x1f) << 2) | (regs[1] >> 6) ) + 1;
	uint64_t hs_div = (regs[0] >> 5) + 4;

	board_dbg("Si57x: RFREQ %08x %08x n1 %d hsdiv %d\n", (uint32_t) (rfreq >> 32), (uint32_t) rfreq, (int)n1, (int)hs_div );

	if( rfreq == 0 )
	{
		board_dbg("strange, rfreq == 0\n");
		return;
	}

	uint64_t f0 = 100000000;
	uint64_t f_xtal = (f0 * hs_div * n1 ) * ( 1ULL << 28 ) / rfreq;

	
	board_dbg("Si57x: xtal frequency = %d Hz\n", (int) f_xtal );

	if( freq_hz )
		*freq_hz = f_xtal;

}

static int si57x_calc_frequency( uint32_t f_xtal, uint32_t freq_hz, uint64_t *rfreq_out, int* hsdiv_out, int* n1_out )
{
	const uint8_t hsdiv_values[] = { 4, 5, 6, 7, 9, 11, 0 };
	int hsdiv_idx, n1;
	const uint64_t f_dco_min = 4850000000;
	const uint64_t f_dco_max = 5670000000;

		for( hsdiv_idx = 0; hsdiv_values[hsdiv_idx] != 0; hsdiv_idx++ )
		{
			for( n1 = 1; n1 <= 255; n1++ )
			{
				if ( n1 && (n1 & 1) )
					continue;

			uint64_t hs_div = hsdiv_values[hsdiv_idx];

			uint64_t f_dco = (uint64_t) freq_hz * hs_div * n1;

			if( f_dco < f_dco_min || f_dco > f_dco_max )
				continue;

			uint64_t rfreq = f_dco * (1ULL<<28) / f_xtal;

			*rfreq_out = rfreq;
			*hsdiv_out = hsdiv_idx;
			*n1_out = n1;

			board_dbg("Si57x: New RFREQ %08x %08x n1 %d hsdiv %d\n", (uint32_t) (*rfreq_out >> 32), (uint32_t) *rfreq_out, (int)*n1_out, (int)*hsdiv_out );

			//found = 1;
			return 0;
		}
	}
	return -1;
}

static void si57x_reset(struct wr_si57x_interface_device *dev )
{
	uint8_t r135 = 1;

	r135 = (1<<7);
	si57x_write( dev, 135, &r135, 1 );
	timer_delay_ms(10);
	r135 =  1;
	si57x_write( dev, 135, &r135, 1 );

}


static int si57x_set_frequency( struct wr_si57x_interface_device *dev, uint32_t f_xtal, uint32_t freq_hz )
{
	uint8_t regs[16];
	uint64_t rfreq;
	int hsdiv;
	int n1;

	if( si57x_calc_frequency ( f_xtal, freq_hz, &rfreq, &hsdiv, &n1 ) < 0 )
		return -1;

	dev->n1 = n1;
	dev->hsdiv = hsdiv;
	dev->rfreq = rfreq;

	regs[12] = (dev->rfreq & 0xff);
	regs[11] = ((dev->rfreq >> 8) & 0xff);
	regs[10] = ((dev->rfreq >> 16) & 0xff);
	regs[9] =  ((dev->rfreq >> 24) & 0xff);
	regs[8] = ((dev->rfreq >>32) & 0x3f) | (((dev->n1-1) & 0xff) << 6);
	regs[7] = (dev->hsdiv << 5) | ((dev->n1-1) >> 2);

	board_dbg("Si57x: New RFREQ %08x %08x n1 %d hsdiv %d\n", (uint32_t) (dev->rfreq >> 32), (uint32_t) dev->rfreq, (int)dev->n1, (int)dev->hsdiv );


	uint8_t r137, r135;

	timer_delay_ms(10);

	writel( (uint32_t) ( rfreq & 0xffffffffULL), dev->base_addr + SI570_REG_RFREQL );
	writel( (uint32_t) ( rfreq >> 32) | (((n1-1) & 0xff) << 8) | (hsdiv << 16), dev->base_addr + SI570_REG_RFREQH );
	writel( SI570_CR_ENABLE | SI570_CR_CLK_DIV_W(200) | SI570_CR_I2C_ADDR_W ( ( dev->i2c_addr << 1 ) ) | SI570_CR_GAIN_W(2), dev->base_addr + SI570_REG_CR );

	si57x_read( dev, 135, &r135, 1 );
	si57x_read( dev, 137, &r137, 1 );
	r137 |= (1<<4); // freeze DCO
	si57x_write( dev, 137, &r137, 1);
	si57x_write( dev, 7, regs + 7, 6 );
	r137 &= ~(1<<4); // unfreeze DCO
	si57x_write( dev, 137, &r137, 1);
	r135 |= (1<<6); // assert NewFreq
	si57x_write( dev, 135, &r135, 1);

	return 0;
}

#if defined(CONFIG_TARGET_AFCZ_V1)

#define PCA9554_REG_IN 0
#define PCA9554_REG_OUT 1
#define PCA9554_REG_INVERT 2
#define PCA9554_REG_CONFIG 3



static uint8_t pca9554_read_reg( struct pca9554_gpio_device *dev, uint8_t reg )
{
	uint8_t rv;
	int err;
	bb_i2c_start(dev->bus);
	err |= bb_i2c_put_byte(dev->bus, dev->i2c_addr << 1);
	bb_i2c_put_byte(dev->bus,  reg );
	bb_i2c_repeat_start(dev->bus );
	err |= bb_i2c_put_byte(dev->bus,  (dev->i2c_addr << 1) | 1);
	bb_i2c_get_byte(dev->bus, &rv, 1 );
	bb_i2c_stop(dev->bus);

	if( err )
	{
		board_dbg("pca9554 not responding [addr = 0x%x]!\n", dev->i2c_addr );
	}

	return rv;
}

static void pca9554_write_reg( struct pca9554_gpio_device *dev, uint8_t reg, uint8_t value )
{
	bb_i2c_start(dev->bus);
	bb_i2c_put_byte(dev->bus, dev->i2c_addr << 1);
	bb_i2c_put_byte(dev->bus,  reg );
	bb_i2c_put_byte(dev->bus,  value );
	bb_i2c_stop(dev->bus);
}

static void pca9554_gpio_out(const struct gpio_pin *pin, int value)
{
	struct pca9554_gpio_device* dev = ( struct pca9554_gpio_device* ) pin->device->priv;


	uint8_t oreg = pca9554_read_reg( dev, PCA9554_REG_OUT );

	if( value )
		oreg |= ( 1<< pin->pin );
	else
		oreg &= ~ ( 1<< pin->pin );


	pca9554_write_reg( dev, PCA9554_REG_OUT, oreg );
}



static void pca9554_gpio_set_dir(const struct gpio_pin *pin, int dir)
{
	struct pca9554_gpio_device* dev = ( struct pca9554_gpio_device* ) pin->device->priv;


	uint8_t dreg = pca9554_read_reg( dev, PCA9554_REG_CONFIG );

	if( ! dir )
		dreg |= ( 1<< pin->pin );
	else
		dreg &= ~ ( 1<< pin->pin );


	pca9554_write_reg( dev, PCA9554_REG_CONFIG, dreg );
	
}


static int pca9554_gpio_in(const struct gpio_pin *pin)
{
	//struct pca9554_gpio_device* dev = ( struct pca9554_gpio_device* ) pin->device->priv;

// fixme: implement
	return 0;
}


static void pca9554_gpio_init( struct pca9554_gpio_device *dev, struct i2c_bus *bus, uint8_t i2c_addr )
{
	dev->bus = bus;
	dev->i2c_addr = i2c_addr;
	dev->gpio.priv = (void *) dev;
	dev->gpio.read_pin = pca9554_gpio_in;
	dev->gpio.set_dir = pca9554_gpio_set_dir;
	dev->gpio.set_out = pca9554_gpio_out;
}
#endif

static void wr_si57x_interface_init( struct wr_si57x_interface_device *dev, uint32_t base_addr, uint8_t i2c_addr )
{

	dev->base_addr = (void *) base_addr;
	dev->gpio_i2c.priv = (void *) dev;
	dev->gpio_i2c.read_pin = si57x_gpio_in;
	dev->gpio_i2c.set_dir = si57x_gpio_set_dir;
	dev->gpio_i2c.set_out = si57x_gpio_out;
	dev->i2c_addr = i2c_addr;
	dev->pin_scl.device = &dev->gpio_i2c;
	dev->pin_scl.pin = SI57X_PIN_SCL;
	dev->pin_sda.device = &dev->gpio_i2c;
	dev->pin_sda.pin = SI57X_PIN_SDA;
	bb_i2c_create( &dev->master, &dev->pin_scl, &dev->pin_sda );
}



// fixme: factor out all this code to a common file (used by sis83k, afcz, ertm)
static int calc_apr(int meas_min, int meas_max, int f_center )
{
	// apr_min is in PPM

	if( f_center < meas_min || f_center > meas_max )
		f_center = (meas_min + meas_max) / 2;

	int64_t delta_low =  meas_min - f_center;
	int64_t delta_hi = meas_max - f_center;
	uint64_t u_delta_low, u_delta_hi;
	int ppm_lo, ppm_hi;

	if(delta_low >= 0)
		return -1;
	if(delta_hi <= 0)
		return -1;

	/* __div64_32 divides 64 by 32; result is in the 64 argument. */
	u_delta_low = -delta_low * 1000000LL;
	__div64_32(&u_delta_low, f_center);
	ppm_lo = (int)u_delta_low;

	u_delta_hi = delta_hi * 1000000LL;
	__div64_32(&u_delta_hi, f_center);
	ppm_hi = (int)u_delta_hi;

	return ppm_lo < ppm_hi ? ppm_lo : ppm_hi;
}

static int gen_rnd(void)
{
	static const uint32_t lcg_m = 1103515245;
	static const uint32_t lcg_i = 12345;	
  	static uint32_t seed = 0;

	seed *= lcg_m;
	seed += lcg_i;
	seed &= 0x7fffffffUL;

	return seed;
}

static int measure_vcxo_freq( int cm_channel, int cm_ref, int gate_freq, int n_steps, uint32_t expected_freq, void (*dac_setter)(int), int *apr, uint32_t *base_freq )
{
	int f_min = 0, f_max = 0;
	int tune_min = 3000;
	int tune_max = 65535;
	int tune_step = (tune_max-tune_min) / n_steps;

	wb_cm_configure( &board.clk_mon, cm_ref, 5, gate_freq );
	wb_cm_set_ref_frequency( &board.clk_mon, CPU_CLOCK );

	int tune = tune_min;
	
	for(;;)
	{

		dac_setter( tune + (gen_rnd() % 3000) - 1500);
		timer_delay_ms(5);
		wb_cm_restart( &board.clk_mon );
		while( ! (wb_cm_read( &board.clk_mon ) & ( 1<< cm_channel) ) )
		{
			dac_setter( tune + (gen_rnd() % 3000) - 1500);
			timer_delay_ms(5);
		}
		
		int f = board.clk_mon.freqs[ cm_channel ];

		if( tune == tune_min )
			f_min = f;
		else if ( tune == tune_max )
			f_max = f;
		
		if(tune == tune_max)
			break;

		board_dbg("Tune: %d f = %d Hz (deltaF = %d Hz)\n", tune, f, f - expected_freq );

		tune += tune_step;
		if( tune > tune_max )
			tune = tune_max;
	}

	dac_setter( 32768 );
	timer_delay(1);

    int l_apr = calc_apr(f_min, f_max, 62500000);

    if( apr )
        *apr = l_apr;

    if( base_freq )
        *base_freq = (f_min + f_max) / 2;

    board_dbg("VCO ch %d:  Low=%d Hz Hi=%d Hz, APR = %d ppm.\n", cm_channel, f_min, f_max, l_apr );

    return 0;
}



static void set_dmtd_dac( int value )
{
	spll_set_dac( -1, value );
}

static void set_main_dac( int value )
{
	spll_set_dac( 0, value );
}

int afcz_check_clocks(void)
{
	//check_vco_freq( AFCZ_CM_CHANNEL_CLK_DMTD, AFCZ_CM_CHANNEL_CLK_RX, set_dmtd_dac );
	//check_vco_freq( AFCZ_CM_CHANNEL_CLK_REF,  AFCZ_CM_CHANNEL_CLK_RX, set_main_dac );

    board_dbg("Check REF VCXO (Si570)\n");
	set_dmtd_dac(32768);
    timer_delay_ms(10);
	measure_vcxo_freq( AFCZ_CM_CHANNEL_CLK_REF, AFCZ_CM_CHANNEL_CLK_DMTD, 10000000, 4, 62500000, set_main_dac, NULL, NULL );

	board_dbg("Check DMTD VCXO\n");
	set_main_dac(32768);
	timer_delay_ms(10);
    measure_vcxo_freq( AFCZ_CM_CHANNEL_CLK_DMTD, AFCZ_CM_CHANNEL_CLK_REF, 100000, 4, 62500000, set_dmtd_dac, NULL, NULL );

	return 0;
}

#if defined(CONFIG_TARGET_AFCZ_V1)
static const struct gpio_pin pin_rtm_4sfp_led_orange = { &board.gpio_rtm_main.gpio, 3 };
static const struct gpio_pin pin_rtm_4sfp_i2c_reset_n = { &board.gpio_rtm_main.gpio, 5 };
static const struct gpio_pin pin_rtm_4sfp_i2c_enable_n = { &board.gpio_rtm_main.gpio, 6 };
static const struct gpio_pin pin_rtm_4sfp_i2c_pgood_n = { &board.gpio_rtm_main.gpio, 4 };


static const struct gpio_pin pin_rtm_4sfp_sfp_tx_disable = { &board.gpio_rtm_sfp.gpio, 1 };

static void sfp_setup(void)
{
	board_dbg("Check RTM & init SFPs...\n");
//	board_dbg("Devices @ AMC\n");
//	bb_i2c_scan( &board.si57x.master );

//	board_dbg("Devices @ RTM\n");
	tca9548_select_channels( &board.si57x.master, 0x70, 1 << AFCZ_I2C_MUX_CHANNEL_RTM );
//	bb_i2c_scan( &board.si57x.master );

	pca9554_gpio_init( &board.gpio_rtm_main, &board.si57x.master, 0x20 ); // fixme : constants
	pca9554_gpio_init( &board.gpio_rtm_sfp, &board.si57x.master, 0x22 ); // fixme : constants

	gen_gpio_set_dir( &pin_rtm_4sfp_i2c_enable_n, 1);
	gen_gpio_set_dir( &pin_rtm_4sfp_i2c_reset_n, 1);

	gen_gpio_out( &pin_rtm_4sfp_i2c_enable_n, 0 );
	gen_gpio_out( &pin_rtm_4sfp_i2c_reset_n, 0 );
	gen_gpio_out( &pin_rtm_4sfp_i2c_reset_n, 1 );

	gen_gpio_set_dir( &pin_rtm_4sfp_i2c_pgood_n, 0 );

	uint8_t p_out = pca9554_read_reg( &board.gpio_rtm_main, PCA9554_REG_OUT );
	uint8_t p_in = pca9554_read_reg( &board.gpio_rtm_main, PCA9554_REG_IN );
	uint8_t p_cfg = pca9554_read_reg( &board.gpio_rtm_main, PCA9554_REG_CONFIG );

	board_dbg("RTM PCA9554 (RTM MAIN GPIO) regs: out=%02x in=%02x cfg=%02x\n", p_out, p_in, p_cfg );
	board_dbg("RTM Power_good_n: %d\n", gen_gpio_in( &pin_rtm_4sfp_i2c_pgood_n ) );

	const int sfp_busses [] = 
	{
		RTM_4SFP_MUX_SFP0,
		RTM_4SFP_MUX_SFP1,
		RTM_4SFP_MUX_SFP2,
		RTM_4SFP_MUX_SFP3,
		RTM_4SFP_MUX_SFP4,
		RTM_4SFP_MUX_SFP5,
		RTM_4SFP_MUX_SFP6,
		-1
	};

	int i;

	for( i = 0; sfp_busses[i] >= 0; i++ )
	{
		// select SFPx
		tca9548_select_channels( &board.si57x.master, 0x74, 1 << sfp_busses[i] );

		gen_gpio_set_dir( &pin_rtm_4sfp_sfp_tx_disable, 1 );
		gen_gpio_out( &pin_rtm_4sfp_sfp_tx_disable, 0 );

		int rv_pca = bb_i2c_devprobe( &board.si57x.master, 0x22 );
		int rv_sfp = bb_i2c_devprobe( &board.si57x.master, 0xa0 >> 1 );

		board_dbg("Probe/init SFP%d: SFP found=%d PCA found=%d\n", sfp_busses[i], rv_sfp, rv_pca );
	}

}
#endif

#if 0
static void afczv1_read_persistent_mac(void)
{
	uint8_t mac_addr[6];

	tca9548_select_channels( &board.si57x.master, 0x70, 1 << AFCZ_I2C_MUX_CHANNEL_RTM );
	
	i2c_eeprom_create( &board.mac_eeprom, &board.si57x.master, AFCZ_I2C_ADDR_MAC_EEPROM, 1 );
	int n_read = i2c_eeprom_read( &board.mac_eeprom, AFCZ_I2C_EEPROM_MAC_OFFSET, mac_addr, 6);

	if( n_read != 6 )
	{
		board_dbg("Failed to get MAC address from MAC EEPROM. Using fallback address.\n");
		mac_addr[0] = 0x22;
		mac_addr[1] = 0x33;
		mac_addr[2] = 0x44;	/* fallback MAC if get_persistent_mac fails */
		mac_addr[3] = 0x55;
		mac_addr[4] = 0x66;
		mac_addr[5] = 0x77;
	}


	board_dbg("Local MAC address from AT25E48: %02x:%02x:%02x:%02x:%02x:%02x\n",
		mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3],
		mac_addr[4], mac_addr[5]);
	ep_set_mac_addr( &wrc_endpoint_dev, mac_addr );
	
	/* ugly hack, but what can I do about this crappy card (with 8 network interfaces)
	   having a single MAC address chip? */

	mac_addr[2] += 1;

	board_dbg("B-Train MAC address from AT25E48: %02x:%02x:%02x:%02x:%02x:%02x\n",
		mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3],
		mac_addr[4], mac_addr[5]);
	ep_set_mac_addr( &board.ep_btrain, mac_addr );
}
#endif

static void afczv2_read_dna_mac( uint8_t *mac )
{
	uint32_t id, ver, nrw, nro;
	uint32_t sn;
	uint32_t dna[3];
	diag_read_info(&id, &ver, &nrw, &nro );
	board_dbg("diags: id %d ver %d nrw %d nro %d\n", id, ver, nrw, nro );
	diag_read_word(nro - 4, DIAG_RO_BANK, &dna[0] );
	diag_read_word(nro - 3, DIAG_RO_BANK, &dna[1] );
	diag_read_word(nro - 2, DIAG_RO_BANK, &dna[2] );
	diag_read_word(nro - 1, DIAG_RO_BANK, &sn );

	board_dbg("S/N %x DNA %08x %08x %08x\n", sn, dna[0], dna[1], dna[2] );

	// well, we can't do anything else than generate this crap from the device's DNA. The serial numbers
	// provided by the MMC don't appear to be really UNIQUE...
	uint32_t seed = dna[0] ^ dna[1] ^ dna[2];
	mac[0] = 0x22;
	mac[1] = 0x33;
	mac[2] = (seed >> 24) & 0xff;
	mac[3] = (seed >> 16) & 0xff;
	mac[4] = (seed >> 8) & 0xff;
	mac[5] = seed & 0xff;
}


static void afczv2_read_persistent_mac(void)
{
	uint8_t mac_addr[6];

	afczv2_read_dna_mac( mac_addr );
	board_dbg("Local MAC address from device DNA: %02x:%02x:%02x:%02x:%02x:%02x\n",
		mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3],
		mac_addr[4], mac_addr[5]);
	ep_set_mac_addr( &wrc_endpoint_dev, mac_addr );
	
	/* ugly hack, but what can I do about this crappy card (with 8 network interfaces)
	   having a single MAC address chip? */

	mac_addr[2] += 1;

	board_dbg("B-Train MAC address from device DNA: %02x:%02x:%02x:%02x:%02x:%02x\n",
		mac_addr[0], mac_addr[1], mac_addr[2], mac_addr[3],
		mac_addr[4], mac_addr[5]);
	ep_set_mac_addr( &board.ep_btrain, mac_addr );
}



int wrc_board_early_init()
{
//	wb_gpio_create( &board.gpio_aux, 0x48000 );
	board_dbg("WR Core AFCZ port starting up\n");    


	wr_si57x_interface_init( &board.si57x, BASE_SI57X_INTERFACE, SI57X_I2C_ADDR );
	
#if defined(CONFIG_TARGET_AFCZ_V1)
	tca9548_select_channels( &board.si57x.master, 0x70, 1 << AFCZ_I2C_MUX_CHANNEL_SI570 );
#endif

	uint8_t regs[16];

	si57x_reset( &board.si57x );

	timer_delay_ms(10);

	si57x_read( &board.si57x, 0, regs, 16 ); 

	uint32_t f_xtal = 0;

	si57x_get_xtal_frequency( &board.si57x, &f_xtal );
	si57x_set_frequency( &board.si57x, f_xtal, 125000000 );

#if defined(CONFIG_TARGET_AFCZ_V1)
	idt8v_clock_mux_init ( &board.clk_mux, &board.si57x.master, IDT8V_I2C_ADDR );
	idt8v_configure_io ( &board.clk_mux, AFCZ_IC33_CLK_SI570_1_IN, 1, 1, 0);
	idt8v_configure_io ( &board.clk_mux, AFCZ_IC33_CLK_SI570_2_IN, 1, 1, 0);
	idt8v_configure_io ( &board.clk_mux, AFCZ_IC33_FPGA_CLK3_OUT, 0, 0, AFCZ_IC33_CLK_SI570_1_IN);
	idt8v_configure_io ( &board.clk_mux, AFCZ_IC33_FPGA_CLK_GTX_CUST2_OUT, 0, 0, AFCZ_IC33_CLK_SI570_1_IN);
    idt8v_configure_io ( &board.clk_mux, AFCZ_IC33_FPGA_FMC2_CLK2_BIDIR_OUT, 0, 0, AFCZ_IC33_CLK_SI570_1_IN);
	idt8v_configure_io ( &board.clk_mux, 10, 0, 0, AFCZ_IC33_CLK_SI570_1_IN);
	idt8v_commit_configuration ( &board.clk_mux );
#endif

	wb_cm_init( &board.clk_mon, BASE_AFCZ_CLOCK_MONITOR, 6 );

#if defined(CONFIG_TARGET_AFCZ_V1)
	sfp_setup();
#endif

	net_rst();
	ep_init( &wrc_endpoint_dev, (void *) BASE_WR_ENDPOINT_MAIN );
	ep_init( &board.ep_btrain, (void *) BASE_WR_ENDPOINT_BTRAIN );
	netif_register_device(&wrc_endpoint_dev, &minic);
	netif_register_device(&board.ep_btrain, NULL);

#if defined (CONFIG_TARGET_AFCZ_V1)
	afczv1_read_persistent_mac();
#endif

#if defined (CONFIG_TARGET_AFCZ_V2)
	afczv2_read_persistent_mac();
#endif


	/* Sleep for 1s to make sure WRS v4.2 always realizes that
	 * the link is down */
	timer_delay_ms(200);
	ep_enable( &wrc_endpoint_dev, 1, 1);
	ep_enable( &board.ep_btrain, 1, 1);
	timer_delay_ms(200);

#if defined(CONFIG_TARGET_AFCZ_V1)
	tca9548_select_channels( &board.si57x.master, 0x70, 1 << AFCZ_I2C_MUX_CHANNEL_SI570 );
#endif

#if 0
	set_dmtd_dac(32767);
	set_main_dac(30000);

	ep_reset_phy(&wrc_endpoint_dev);
	afcz_check_clocks();

// cross-check the REF and DDMTD clocks

	wb_cm_configure( &board.clk_mon, AFCZ_CM_CHANNEL_CLK_DMTD, 5, 1000000 );
	wb_cm_set_ref_frequency( &board.clk_mon, CPU_CLOCK );
	wb_cm_restart( &board.clk_mon );
	timer_delay_ms(4000);
	wb_cm_read(  &board.clk_mon );
	wb_cm_show(  &board.clk_mon );

#endif

	return 0;
}

#define AFCZ_CLOCK_MON_TIMEOUT_MS 4000

#if 0
int afcz_check_clocks()
{
	wb_cm_configure( &board.clk_mon, AFCZ_CM_CHANNEL_CLK_SYS, 5, 10000000 );
	wb_cm_set_ref_frequency( &board.clk_mon, CPU_CLOCK );
	wb_cm_restart(&board.clk_mon);
	int timeout_cntr = 0;

	while( ! (wb_cm_read( &board.clk_mon ) & ( 1<< AFCZ_CM_CHANNEL_CLK_RX) ) )
	{
		timer_delay_ms(100);
		timeout_cntr+=100;
		if( timeout_cntr > AFCZ_CLOCK_MON_TIMEOUT_MS )
		{
			pp_printf("Can't get the PHY RX clock measurement. Aborting oscillator test.\n");
			return -1;
		}
	}


	pp_printf("Checking clocks: RX clock freq = %d Hz\n", board.clk_mon.freqs[ AFCZ_CM_CHANNEL_CLK_RX ]);
	
	pp_printf("Checking DDMTD and REF clock frequencies:\n");
//	afcz_check_clocks();

	return 0;
}
#endif

int wrc_board_init()
{
    static int32_t flash_entry_points[2];

	/* initialize I2C bus */
	bb_i2c_init(&dev_i2c_fmc);

	/* init storage (we use the SPI flash on eRTM14) */
	bb_spi_create( &spi_wrc_flash,
		&pin_sysc_spi_ncs,
		&pin_sysc_spi_mosi,
		&pin_sysc_spi_miso,
		&pin_sysc_spi_sclk, 10 );

	spi_wrc_flash.rd_falling_edge = 1;
	int retries = 1000000;
	uint32_t id;
	
	flash_entry_points[0] = 0x1f00000;
    flash_entry_points[1] = -1;

    
    /* init storage (we use the SPI flash on eRTM14) */
    storage_spiflash_create( &wrc_storage_dev, &wrc_flash_dev );

	do {
		spi_flash_create( &wrc_flash_dev, &spi_wrc_flash, 0x10000, 0x1f00000 );
		retries--;
		id = spi_flash_read_id( &wrc_flash_dev );

	} while ( retries && (id == 0 || id == 0xffffff) );

	
	storage_spiflash_create( &wrc_storage_dev, &wrc_flash_dev );
	wrc_storage_dev.entry_points = &flash_entry_points[0];
	storage_mount( &wrc_storage_dev );

	return 0;
}

int wrc_board_create_tasks()
{
    return 0;
}
