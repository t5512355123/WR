/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2019 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <limits.h>
#include <string.h>

#include <sys/errno.h>

#include "board.h"
#include "wrc-debug.h"
#include "dev/gpio.h"
#include "dev/74x595.h"
#include "dev/ad7888.h"
#include "dev/syscon.h"
#include "util.h"
#include "ertm15_rf_distr.h"

#ifndef INT32_MAX
    #define INT32_MAX INT_MAX
#endif

#ifndef INT32_MIN
    #define INT32_MIN INT_MIN
#endif

#define ERTM15_PWR_BIAS -130 // mBm offset adjustment for measured LO/REF power values

static const struct gpio_pin pin_lo_ctrl_ser = { &board.gpio_aux, 39 };
static const struct gpio_pin pin_lo_ctrl_updtclk = { &board.gpio_aux, 40 };
static const struct gpio_pin pin_lo_ctrl_shftclk = { &board.gpio_aux, 41 };

static const struct gpio_pin pin_ref_ctrl_ser = { &board.gpio_aux, 42 };
static const struct gpio_pin pin_ref_ctrl_updtclk = { &board.gpio_aux, 43 };
static const struct gpio_pin pin_ref_ctrl_shftclk = { &board.gpio_aux, 44 };

static struct gpio_device gpio_rfsw_ref;
static struct gpio_device gpio_rfsw_lo;


// mapping between x595 shift reg (IC26..28 on eRTM15 and the RF switch control pins)
static const struct pin_mapping
{
    uint8_t path;           // RF path (REF/LO)
    uint8_t channel;        // MTCA.4 channel
    uint8_t ctrl1, ctrl2;   // RF switch pin indices (CTRL1/CTRL2)
} rf_switch_sreg_pin_mapping[] = {
    // REF outputs
    {ERTM15_RF_REF, 4, 8 + 5, 8 + 4},
    {ERTM15_RF_REF, 5, 8 + 6, 8 + 7},
    {ERTM15_RF_REF, 6, 8 + 1, 8 + 0},
    {ERTM15_RF_REF, 7, 8 + 3, 8 + 2},
    {ERTM15_RF_REF, 8, 4, 5},
    {ERTM15_RF_REF, 9, 6, 7},
    {ERTM15_RF_REF, 10, 16 + 7, 16 + 6},
    {ERTM15_RF_REF, 11, 2, 3},
    {ERTM15_RF_REF, 12, 0, 1},
    
    // LO outputs
    {ERTM15_RF_LO, 4,  16 + 7, 16 + 6}, // ic28 7, 6
    {ERTM15_RF_LO, 5,  0  + 6, 0  + 7}, // ic26 6, 7
    {ERTM15_RF_LO, 6,  0  + 4, 0  + 5}, // ic26 4, 5
    {ERTM15_RF_LO, 7,  0  + 0, 0  + 1}, // ic26 15, 1
    {ERTM15_RF_LO, 8,  0  + 2, 0  + 3}, // ic26 2, 3
    {ERTM15_RF_LO, 9,  8  + 6, 8  + 7}, // ic27 6, 7
    {ERTM15_RF_LO, 10, 8  + 5, 8  + 4}, // ic27 5, 4
    {ERTM15_RF_LO, 11, 8  + 1, 8  + 0}, // ic27 1, 15
    {ERTM15_RF_LO, 12, 8  + 3, 8  + 2}, // ic27 3, 2

    {ERTM15_RF_REF, 0, 0, 0}};

static const struct pin_mapping* find_pins_for_channel ( int path, int channel )
{
    int i;
    for(i=0; rf_switch_sreg_pin_mapping[i].channel !=0; i++ )
    {
        if( rf_switch_sreg_pin_mapping[i].channel == channel && rf_switch_sreg_pin_mapping[i].path == path )
        {
            return &rf_switch_sreg_pin_mapping[i];
        }
    }
    return NULL;
}

static int rf_switch_set( int path, int channel, int state)
{
    struct gpio_device *gpio = ( path == ERTM15_RF_REF ? &gpio_rfsw_ref : &gpio_rfsw_lo);
    const struct pin_mapping *pins = find_pins_for_channel( path, channel );
    struct gpio_pin ctrl1, ctrl2;

    ctrl1.device = gpio;
    ctrl1.pin = pins->ctrl1;
    ctrl2.device = gpio;
    ctrl2.pin = pins->ctrl2;
    

    if(!pins)
        return -1;
    
// HSWA2-30DR+ I/O CTRL pins function:
// CTRL1 = 0, CTRL2 = 0: OFF
// CTRL1 = 0, CTRL2 = 1: MONITOR
// CTRL1 = 1, CTRL2 = 0: ON

    switch(state)
    {
        case ERTM15_RF_OUT_ON:
            gen_gpio_out( &ctrl1, 1 );
            gen_gpio_out( &ctrl2, 0 );
            break;
        case ERTM15_RF_OUT_MONITOR:
            gen_gpio_out( &ctrl1, 0 );
            gen_gpio_out( &ctrl2, 1 );
            break;
        case ERTM15_RF_OUT_OFF:
            gen_gpio_out( &ctrl1, 0 );
            gen_gpio_out( &ctrl2, 0 );
            
        break;
    }
   
    return 0;
}



void ertm15_rf_distr_init( struct ertm15_rf_distribution_device *dev, struct ad7888_device *pwr_mon_adc )
{
    memset(dev, 0, sizeof(struct ertm15_rf_distribution_device));
    x595_gpio_create ( &gpio_rfsw_ref, 3, &pin_ref_ctrl_updtclk, &pin_ref_ctrl_shftclk, NULL, &pin_ref_ctrl_ser );
    x595_gpio_create ( &gpio_rfsw_lo, 3, &pin_lo_ctrl_updtclk, &pin_lo_ctrl_shftclk, NULL, &pin_lo_ctrl_ser );

    //x595_test( &gpio_rfsw_ref );

    dev->pwr_ref_valid = 0;
    dev->pwr_lo_valid = 0;
    dev->ref_enabled = 0;
    dev->lo_enabled = 0;
    dev->pwr_ref_valid = 0;
    dev->pwr_mon_adc = pwr_mon_adc;

    // disable all RF outputs to the backplane
    ertm15_update_rf_switches( dev );
}

// fixed point logarithm code from: https://github.com/dmoulding/log2fix/blob/master/log2fix.c

#define INV_LOG2_E_Q1DOT31  (0x58b90bfcULL) // Inverse log base 2 of e
#define INV_LOG2_10_Q1DOT31 (0x268826a1ULL) // Inverse log base 2 of 10

int64_t log2fix (uint64_t x, size_t precision)
{
    // This implementation is based on Clay. S. Turner's fast binary logarithm
    // algorithm[1].

    int64_t b = 1UL << (precision - 1);
    int64_t y = 0;

    if (precision < 1 || precision > 31) {
        errno = -EINVAL;
        return INT32_MAX; // indicates an error
    }

    if (x == 0) {
        return INT32_MIN; // represents negative infinity
    }

    while (x < 1UL << precision) {
        x <<= 1;
        y -= 1UL << precision;
    }

    while (x >= 2UL << precision) {
        x >>= 1;
        y += 1UL << precision;
    }

    uint64_t z = x;

    size_t i;
    for (i = 0; i < precision; i++) {
        z = z * z >> precision;
        if (z >= 2UL << precision) {
            z >>= 1;
            y += b;
        }
        b >>= 1;
    }

    return y;
}

int32_t log10fix (uint64_t x, size_t precision)
{
    uint64_t t;

    t = log2fix(x, precision) * INV_LOG2_10_Q1DOT31;

    return t >> 31;
}

// takes raw ADC readout (0..4095), returns normalized power value in mBm
static int convert_power( int adc_value )
{
//    pp_printf("ADCV %d\n", adc_value );

    // ADC full scale: 0..4095 - 0..2.5 V
    // LMH2120: 0 dBm = 2V (see datasheet Figure 17)
    // LMH2120 pre-attenuator: 15 dB

    int precision_bits = 16;

    int32_t f_adc_voltage = ( (int64_t)adc_value << precision_bits) * 25LL / 4096LL; // volts, fixed point
    const int32_t f_2V = (20LL << precision_bits);
    const int32_t f_log_2V_0dBm = log10fix( f_2V, precision_bits );
    int32_t f_log_input = log10fix( f_adc_voltage, precision_bits );
    int32_t pwr =  ( ( 2000LL * (int64_t)(f_log_input - f_log_2V_0dBm) ) >> precision_bits ) + 1500;

    pwr += ERTM15_PWR_BIAS;

    return (int) (pwr);
}


#define ADC_CH_LO_DDS_PA 0
#define ADC_CH_LO_DDS_DISTR 1
#define ADC_CH_REF_DDS_PA 2
#define ADC_CH_REF_DDS_DISTR 3

#define ADC_CHANNEL_MASK 0xf


int ertm15_rf_distr_pwrmon_update(  struct ertm15_rf_distribution_device *dev )
{
    //pp_printf("ST %d\n", dev->pwr_meas_state);
    switch(dev->pwr_meas_state)
    {
        case PWR_MEAS_STATE_IDLE:
            return 0;

        case PWR_MEAS_STATE_START:
            tmo_init( &dev->pwr_meas_tmo, PWR_MEAS_STABILIZE_TMO_MS );
            dev->pwr_meas_channel = ERTM14_RF_OUT_MIN_ID;
            dev->pwr_meas_state = PWR_MEAS_STATE_PICK_CHANNEL;
            dev->pwr_meas_start_tics = timer_get_tics();

            if( dev->pwr_meas_force )
            {
                int i;

                // all channels to OFF, so that they are terminated
                for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i ++ )
                {
                    rf_switch_set( ERTM15_RF_REF, i, ERTM15_RF_OUT_OFF );
                    rf_switch_set( ERTM15_RF_LO, i, ERTM15_RF_OUT_OFF );
                }

                dev->pwr_ref_valid = 0;
                dev->pwr_lo_valid = 0;
            }

            break;

        case PWR_MEAS_STATE_PICK_CHANNEL:
        {
            if( ! tmo_expired( &dev->pwr_meas_tmo ) )
                break;

            tmo_restart( &dev->pwr_meas_tmo );

            if( dev->pwr_meas_force || !(dev->ref_enabled & (1<<dev->pwr_meas_channel) ) )
                rf_switch_set( ERTM15_RF_REF, dev->pwr_meas_channel, ERTM15_RF_OUT_MONITOR );

            if( dev->pwr_meas_force || !(dev->lo_enabled & (1<<dev->pwr_meas_channel) ) )
                rf_switch_set( ERTM15_RF_LO, dev->pwr_meas_channel, ERTM15_RF_OUT_MONITOR );

            dev->pwr_meas_state = PWR_MEAS_STATE_START_ADC;
            break;
        }

        case PWR_MEAS_STATE_START_ADC:
        {
            if( ! tmo_expired( &dev->pwr_meas_tmo ) )
                break;

            ad7888_start_conversion( dev->pwr_mon_adc, ADC_CHANNEL_MASK );
            dev->pwr_meas_state = PWR_MEAS_STATE_READ_ADC;

            break;
        }

        case PWR_MEAS_STATE_READ_ADC:
        {
            ad7888_poll( dev->pwr_mon_adc );
            //pp_printf("CH %d V %x\n", dev->pwr_meas_channel, dev->pwr_mon_adc->channel_valid);
            if( dev->pwr_mon_adc->channel_valid != ADC_CHANNEL_MASK )
                break;

            dev->pwr_ref_in = convert_power( dev->pwr_mon_adc->channel[ADC_CH_REF_DDS_PA] );
            dev->pwr_lo_in = convert_power( dev->pwr_mon_adc->channel[ADC_CH_LO_DDS_PA] );

            int raw_pwr_ref = ad7888_meas_channel( dev->pwr_mon_adc, ADC_CH_REF_DDS_DISTR );
            int raw_pwr_lo = ad7888_meas_channel( dev->pwr_mon_adc, ADC_CH_LO_DDS_DISTR );

            if(dev->pwr_meas_force || !(dev->ref_enabled & (1<<dev->pwr_meas_channel) ) )
                dev->pwr_ref_ch[ dev->pwr_meas_channel ] = convert_power( raw_pwr_ref );
            if(dev->pwr_meas_force || !(dev->lo_enabled & (1<<dev->pwr_meas_channel) ) )
                dev->pwr_lo_ch[ dev->pwr_meas_channel ] = convert_power( raw_pwr_lo );

            //board_dbg("refin %d loin %d ref%d %d lo%d %d", dev->pwr_ref_in, dev->pwr_lo_in,
            //dev->pwr_meas_channel, dev->pwr_ref_ch[dev->pwr_meas_channel],
            //dev->pwr_meas_channel, dev->pwr_lo_ch[dev->pwr_meas_channel] );

            if( dev->pwr_meas_force || !(dev->lo_enabled & (1<<dev->pwr_meas_channel) ) )
                rf_switch_set( ERTM15_RF_LO, dev->pwr_meas_channel, ERTM15_RF_OUT_OFF );
            if( dev->pwr_meas_force || !(dev->ref_enabled & (1<<dev->pwr_meas_channel) ) )
                rf_switch_set( ERTM15_RF_REF, dev->pwr_meas_channel, ERTM15_RF_OUT_OFF );

            if( dev->pwr_meas_channel >= ERTM14_RF_OUT_MAX_ID )
                dev->pwr_meas_state = PWR_MEAS_STATE_FINISH;
            else
            {
                dev->pwr_meas_channel++;
                tmo_restart( &dev->pwr_meas_tmo );
                dev->pwr_meas_state = PWR_MEAS_STATE_PICK_CHANNEL;
            }

            break;

        }

        case PWR_MEAS_STATE_FINISH:
        {
            if( dev->pwr_meas_force ) // restore state of channels that have been squelched during measurement
            {
                int i;
                for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i ++ )
                {
                    rf_switch_set( ERTM15_RF_REF, i, dev->ref_enabled & (1<<i) ? ERTM15_RF_OUT_ON : ERTM15_RF_OUT_OFF );
                    rf_switch_set( ERTM15_RF_LO, i, dev->lo_enabled & (1<<i) ? ERTM15_RF_OUT_ON : ERTM15_RF_OUT_OFF );
                }

                dev->pwr_lo_valid = ERTM14_ALL_RF_OUT_ID_MASK;
                dev->pwr_ref_valid = ERTM14_ALL_RF_OUT_ID_MASK;
            }
            else
            {
                dev->pwr_lo_valid = ERTM14_ALL_RF_OUT_ID_MASK & ~( dev->lo_enabled );
                dev->pwr_ref_valid = ERTM14_ALL_RF_OUT_ID_MASK & ~( dev->ref_enabled );
            }

            //uint32_t dt = timer_get_tics() - dev->pwr_meas_start_tics;
            //board_dbg("pwr_meas took %d ms, forced=%d\n", dt, dev->pwr_meas_force );

            dev->pwr_meas_force = 0;
            dev->pwr_meas_state = PWR_MEAS_STATE_DONE;
            break;
        }

        default:
            break;
    }

    return 0;
}

int ertm15_rf_distr_measure_power_restart( struct ertm15_rf_distribution_device *dev, int force )
{
    if( force )
    {
        dev->pwr_meas_force = 1;
        dev->pwr_lo_valid = 0;
        dev->pwr_ref_valid = 0;
        dev->pwr_meas_state = PWR_MEAS_STATE_START;
        ertm15_rf_distr_pwrmon_update( dev );
    }
    else
    {
        dev->pwr_meas_state = PWR_MEAS_STATE_START;
    }


    return 0;
}

int ertm15_rf_distr_measure_power ( struct ertm15_rf_distribution_device *dev )
{
    //pp_printf("Restart\n");
    ertm15_rf_distr_measure_power_restart( dev, 0 );

    while( dev->pwr_meas_state != PWR_MEAS_STATE_DONE )
        ertm15_rf_distr_pwrmon_update( dev );

    return 0;
}

#if 0
    
    int i;
    ad7888_start_conversion( dev->pwr_mon_adc, ADC_CHANNEL_MASK );

    while( dev->pwr_mon_adc->channel_valid != ADC_CHANNEL_MASK )
    {
        ad7888_poll( dev->pwr_mon_adc );
        timer_delay_ms(1);
    }

    dev->pwr_ref_in = convert_power( dev->pwr_mon_adc->channel[ADC_CH_REF_DDS_PA] );
    dev->pwr_lo_in = convert_power( dev->pwr_mon_adc->channel[ADC_CH_LO_DDS_PA] );

    timer_delay_ms(1);

    for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i ++ )
    {
        dev->pwr_ref_valid &= ~(1<<i);
        if( ! (dev->ref_enabled & (1<<i) ) )
        {
            rf_switch_set( ERTM15_RF_REF, i, ERTM15_RF_OUT_MONITOR );
            timer_delay_ms(10);
            int raw_pwr = ad7888_meas_channel( dev->pwr_mon_adc, ADC_CH_REF_DDS_DISTR );
            dev->pwr_ref_ch[ i ] = convert_power( raw_pwr );
            dev->pwr_ref_valid |= (1<<i);
            rf_switch_set( ERTM15_RF_REF, i, ERTM15_RF_OUT_OFF );
        }

        dev->pwr_lo_valid &= ~(1<<i);
        if( ! (dev->lo_enabled & (1<<i) ) )
        {
            rf_switch_set( ERTM15_RF_LO, i, ERTM15_RF_OUT_MONITOR );
            timer_delay_ms(10);
            int raw_pwr = ad7888_meas_channel( dev->pwr_mon_adc, ADC_CH_LO_DDS_DISTR );
            dev->pwr_lo_ch[ i ] = convert_power( raw_pwr );
            dev->pwr_lo_valid |= (1<<i);
            rf_switch_set( ERTM15_RF_LO, i, ERTM15_RF_OUT_OFF );
        }
    }

    return 0;
}

int ertm15_rf_distr_measure_power ( struct ertm15_rf_distribution_device *dev )
{
    int i;
    ad7888_start_conversion( dev->pwr_mon_adc, ADC_CHANNEL_MASK );

    while( dev->pwr_mon_adc->channel_valid != ADC_CHANNEL_MASK )
    {
        ad7888_poll( dev->pwr_mon_adc );
        timer_delay_ms(1);
    }

    dev->pwr_ref_in = convert_power( dev->pwr_mon_adc->channel[ADC_CH_REF_DDS_PA] );
    dev->pwr_lo_in = convert_power( dev->pwr_mon_adc->channel[ADC_CH_LO_DDS_PA] );

    timer_delay_ms(1);

    for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i ++ )
    {
        dev->pwr_ref_valid &= ~(1<<i);
        if( ! (dev->ref_enabled & (1<<i) ) )
        {
            rf_switch_set( ERTM15_RF_REF, i, ERTM15_RF_OUT_MONITOR );
            timer_delay_ms(10);
            int raw_pwr = ad7888_meas_channel( dev->pwr_mon_adc, ADC_CH_REF_DDS_DISTR );
            dev->pwr_ref_ch[ i ] = convert_power( raw_pwr );
            dev->pwr_ref_valid |= (1<<i);
            rf_switch_set( ERTM15_RF_REF, i, ERTM15_RF_OUT_OFF );
        }

        dev->pwr_lo_valid &= ~(1<<i);
        if( ! (dev->lo_enabled & (1<<i) ) )
        {
            rf_switch_set( ERTM15_RF_LO, i, ERTM15_RF_OUT_MONITOR );
            timer_delay_ms(10);
            int raw_pwr = ad7888_meas_channel( dev->pwr_mon_adc, ADC_CH_LO_DDS_DISTR );
            dev->pwr_lo_ch[ i ] = convert_power( raw_pwr );
            dev->pwr_lo_valid |= (1<<i);
            rf_switch_set( ERTM15_RF_LO, i, ERTM15_RF_OUT_OFF );
        }
    }

    return 0;
}
#endif


void ertm15_rf_distr_output_enable( struct ertm15_rf_distribution_device *dev, int path, int channel, int enabled )
{
    uint16_t* mask = (path == ERTM15_RF_LO ? &dev->lo_enabled : &dev->ref_enabled );

    if( enabled )
        *mask |= ( 1 << channel );
    else
        *mask &= ~( 1 << channel );
}

void ertm15_update_rf_switches( struct ertm15_rf_distribution_device *dev )
{
    int i;

    for( i = 0; rf_switch_sreg_pin_mapping[i].channel != 0; i++ )
    {
        const struct pin_mapping* p = &rf_switch_sreg_pin_mapping[i];

        int enabled = ( p->path == ERTM15_RF_LO ? dev->lo_enabled : dev->ref_enabled ) & (1 << p->channel );

//        board_dbg("rf_distr: switch %s ch %d -> %s\n", p->path == ERTM15_RF_LO ? "LO" : "REF", p->channel, enabled ? "ON" : "OFF" );
        rf_switch_set( p->path, p->channel, enabled ? ERTM15_RF_OUT_ON : ERTM15_RF_OUT_OFF );
    }
}

int ertm15_rf_distr_is_pwrmon_idle( struct ertm15_rf_distribution_device *dev )
{
    return dev->pwr_meas_state == PWR_MEAS_STATE_DONE || dev->pwr_meas_state == PWR_MEAS_STATE_IDLE;
}
