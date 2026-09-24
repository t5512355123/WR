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

/*
    LPDC PHY Calibration code.

    Specific for Kintex-7 devices on the WR2RF-VME and eRTM14/15 cards ONLY!
*/


#include <string.h>
#include <board.h>
#include "dev/syscon.h"
#include "dev/endpoint.h"
#include <softpll_ng.h>
#include "storage.h"
#include "util.h"
#include "wrc-debug.h"
#include "wrc-task.h"

#include <hw/ep_mdio_regs.h>
#include <hw/lpdc_mdio_regs.h>

#include "dev/clock_monitor.h"
#include "sfp.h"

/* middle of clock cycle seems the safest, we observed glitches around 15000->1000 ps */
#define LPDC_COARSE_PHASE_MIN_PS 8500    /* ps */
#define LPDC_COARSE_PHASE_MAX_PS 9000    /* ps */
#define LPDC_FINE_PHASE_TOLLERANCE_PS 40 /* ps */

// number of raw DDMTD phase samples used to measure the RX/TX clock phases
#define LPDC_NUM_PTRACKER_SAMPLES 10 

#define LPDC_TARGET_COMMA_POS 0

#define LPDC_MDIO_CTRL_DMTD_SOURCE_TXOUTCLK (1 << LPDC_MDIO_CTRL_DMTD_CLK_SEL_SHIFT)
#define LPDC_MDIO_CTRL_DMTD_SOURCE_RXRECCLK (0 << LPDC_MDIO_CTRL_DMTD_CLK_SEL_SHIFT)

#define TX_SETUP_STATE_START 0
#define TX_SETUP_STATE_RESET_PCS 1
#define TX_SETUP_STATE_WAIT_TX_PLL_LOCK 2
#define TX_SETUP_STATE_MEASURE_PHASE 3
#define TX_SETUP_DONE 4
#define TX_SETUP_VALIDATE 5
#define TX_SETUP_STATE_DISABLED 6
#define TX_SETUP_STATE_WAIT_SPLL_LOCK 7
#define TX_SETUP_STATE_WAIT_TX_CLK_STABILIZE 8

#define RX_SETUP_STATE_INIT 0
#define RX_SETUP_STATE_RESET_PCS 1
#define RX_SETUP_STATE_WAIT_LOCK 2
#define RX_SETUP_STATE_MEASURE_PHASE 3
#define RX_SETUP_DONE 4
#define RX_SETUP_VALIDATE 5
#define RX_SETUP_STATE_DISABLED 6
#define RX_SETUP_STATE_CHECK_EARLY_LINK 7
#define RX_SETUP_STATE_WAIT_RX_RESET_DONE 8
#define RX_SETUP_STATE_WAIT_GEARBOX_PLL_LOCKED 9
#define RX_SETUP_STATE_BUILD_COMMA_HISTOGRAM 10

#define FSM_DEBUG_REFRESH_PERIOD_MS 1000
#define FSM_PHY_LOCK_TIMEOUT_MS 1000
#define FSM_SPLL_LOCK_TIMEOUT_MS 10000
#define FSM_DMTD_TIMEOUT_MS 100
#define FSM_EARLY_LINK_UP_TIMEOUT_MS 100
#define FSM_STABILIZE_TIMEOUT_MS 100

#define LPDC_EXTRA_DEBUG

#define LPDC_NUM_PATTERN_WORDS 8
#define LPDC_NUM_COMMA_POSITIONS 80
#define LPDC_RX_OVERSAMPLE 4

struct comma_histogram
{
    uint16_t bins[ LPDC_NUM_COMMA_POSITIONS ];
    int total_samples;
};

struct wrc_port_tx_setup_state
{
    int state;
    int cnt;
    int cal_saved_phase;
    int cal_saved_phase_valid;
    int cal_file_updated;
    int measured_phase;
    int expected_phase;
    int tollerance;
    int update_cnt;
    int expected_phase_valid;
    timeout_t phy_lock_timeout;
    timeout_t spll_lock_timeout;
    timeout_t dmtd_timeout;
    int tx_delta_correction;
};

struct wrc_port_rx_setup_state
{
	int cpos_stat[20];
	int state;
	int attempts;
    int prev_link_up;
    timeout_t link_timeout;
    timeout_t stabilize_timeout;
    struct comma_histogram comma_hist;
};

struct wrc_lpdc_state
{
    struct wrc_port_tx_setup_state tx_state;
    struct wrc_port_rx_setup_state rx_state;
    struct wr_endpoint_device *endpoint;
};

static inline void mdio_lpdc_write(struct wrc_lpdc_state *lpdc, int location, uint16_t value)
{
    ep_pcs_write(lpdc->endpoint, location + EP_MDIO_PHY_SPECIFIC_REGS, value);
}

static inline uint16_t mdio_lpdc_read(struct wrc_lpdc_state *lpdc, int location)
{
    return ep_pcs_read(lpdc->endpoint, location + EP_MDIO_PHY_SPECIFIC_REGS);
}

static void mdio_lpdc_set_bits( struct wrc_lpdc_state *lpdc, uint16_t reg, uint16_t mask )
{
    uint16_t rdbk = mdio_lpdc_read( lpdc, reg );
    rdbk |= mask;
    mdio_lpdc_write( lpdc, reg, rdbk );
}

static void mdio_lpdc_clear_bits( struct wrc_lpdc_state *lpdc, uint16_t reg, uint16_t mask )
{
    uint16_t rdbk = mdio_lpdc_read( lpdc, reg );
    rdbk &= ~mask;
    mdio_lpdc_write( lpdc, reg, rdbk );
}

static inline void mdio_xdrp_write(struct wr_endpoint_device *dev, int location, uint16_t value)
{
    ep_pcs_write(dev,
    location + EP_MDIO_PHY_SPECIFIC_REGS + LPDC_MDIO_DRP_REGS,
    value);
}

static inline uint16_t mdio_xdrp_read(struct wr_endpoint_device *dev, int location){
    return ep_pcs_read(dev,  
    location + EP_MDIO_PHY_SPECIFIC_REGS + LPDC_MDIO_DRP_REGS);
}


void dump_xdrp_regs(struct wr_endpoint_device *dev)
{
    phy_dbg("[lpdc] XDRP regs dump:\n");
    int i;
    for(i=0;i<128;i++)
        phy_dbg("     R%d = %04x\n", i, mdio_xdrp_read(dev, i*4));
}

static void tx_fsm_init(struct wrc_port_tx_setup_state *fsm)
{
    fsm->state = TX_SETUP_STATE_START;
    fsm->expected_phase = 0;
    fsm->expected_phase_valid = 0;
    fsm->tollerance = 300;
    fsm->update_cnt = 0;
    fsm->cal_saved_phase_valid = 0;
    fsm->cal_saved_phase = 0;
    fsm->cal_file_updated = 0;
    fsm->cnt = 0;

    /* FIXME: is cal_saved_phase unsigned? uint32_t? declare it so
     * at the wrc_port_tx_setup_state structure */
    if( !storage_get_calibration_parameter( CAL_PARAM_PHY_TARGET_TX_PHASE, (uint32_t *)&fsm->cal_saved_phase )
	&& fsm->cal_saved_phase != -1)
    {
        phy_dbg("[lpdc] TX target phase from calibration data: %d ps\n", fsm->cal_saved_phase);
        fsm->cal_saved_phase_valid = 1;
    }
}

static int tx_fsm_update(struct wrc_lpdc_state *lpdc)
{
    struct wrc_port_tx_setup_state *fsm = &lpdc->tx_state;

    switch (fsm->state)
    {
        case TX_SETUP_STATE_START:
        {
         	spll_init( SPLL_MODE_FREE_RUNNING_MASTER, 0, 0 );
            spll_set_ptracker_average_samples( 0, LPDC_NUM_PTRACKER_SAMPLES );
            tmo_init(&fsm->spll_lock_timeout, FSM_SPLL_LOCK_TIMEOUT_MS);
            ep_sfp_enable( lpdc->endpoint, 0 );
            fsm->state = TX_SETUP_STATE_WAIT_SPLL_LOCK;
            break;
        }

    case TX_SETUP_STATE_WAIT_SPLL_LOCK:
    {
        if( tmo_expired( &fsm->spll_lock_timeout ) )
        {
            phy_dbg("[lpdc] can't lock the SoftPLL. This is necessary for PHY calibration to continue. Retrying...\n");
            tmo_restart( &fsm->spll_lock_timeout );
            fsm->state = TX_SETUP_STATE_START;
            break;
        }

        if( spll_check_lock( 0 ) )
        {
            spll_enable_ptracker(0, 0);

            mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_RX_SW_RESET | LPDC_MDIO_CTRL_DMTD_SOURCE_TXOUTCLK );
            fsm->state = TX_SETUP_STATE_RESET_PCS;

            phy_dbg("[lpdc] SPLL locked\n");
        }

        break;
    }

    case TX_SETUP_STATE_RESET_PCS:
    {
        timeout_t qpll_tmo;
        phy_dbg("[lpdc] TX reset PCS\n");

        spll_enable_ptracker(0, 0);

        // reset everything
        mdio_lpdc_set_bits(lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_TX_SW_RESET | LPDC_MDIO_CTRL_RX_SW_RESET | LPDC_MDIO_CTRL_PLL_SW_RESET | LPDC_MDIO_CTRL_AUX_RESET );
        // release QPLL reset
        mdio_lpdc_clear_bits(lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_PLL_SW_RESET );
        // wait for QPLL lock
        
        tmo_init(&qpll_tmo, 5);
        for(;;) {
            uint16_t stat = mdio_lpdc_read( lpdc, LPDC_MDIO_STAT);
            
            if( stat & LPDC_MDIO_STAT_PLL_LOCKED )
                break;
            
            if( tmo_expired( &qpll_tmo ) )
            {
                phy_dbg("[lpdc] Can't lock GTX QPLL. Faulty bitstream?\n");
                fsm->state = TX_SETUP_STATE_DISABLED;
                return -1;
            }
        }

        // QPLL ok: un-reset TX path
        mdio_lpdc_clear_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_TX_SW_RESET );
        usleep(100);
        // TX path ready, enable TXUSRPLL
        mdio_lpdc_clear_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_AUX_RESET );

        tmo_init( &fsm->phy_lock_timeout, FSM_PHY_LOCK_TIMEOUT_MS );
        fsm->state = TX_SETUP_STATE_WAIT_TX_PLL_LOCK;

        break;
    }

    case TX_SETUP_STATE_WAIT_TX_PLL_LOCK:
    {
        uint32_t stat = mdio_lpdc_read(lpdc, LPDC_MDIO_STAT);
        if (stat & LPDC_MDIO_STAT_TX_RST_DONE)
        {
            fsm->state = TX_SETUP_STATE_WAIT_TX_CLK_STABILIZE;
            tmo_init(&fsm->phy_lock_timeout, 10 );
        }
        else if( tmo_expired(&fsm->phy_lock_timeout) )
        {
            fsm->state = TX_SETUP_STATE_RESET_PCS;
            phy_dbg("TXUSRPLL lock timeout, retrying... [LPDC_STAT=0x%04x]\n", stat );
        }
        break;
    }

    case TX_SETUP_STATE_WAIT_TX_CLK_STABILIZE:
    {
        if( !tmo_expired( &fsm->phy_lock_timeout ) )
            return 0;

        spll_set_ptracker_average_samples( 0, 10 ); // default for SPLL
        spll_enable_ptracker(0, 1);
        tmo_init( &fsm->dmtd_timeout, FSM_DMTD_TIMEOUT_MS );
        fsm->state = TX_SETUP_STATE_MEASURE_PHASE;
        break;
    }

    case TX_SETUP_STATE_MEASURE_PHASE:
    {
        int32_t phase;
        int enabled; //, p2;
        int rv = spll_read_ptracker(0, &phase, &enabled);


        if (!rv)
        {
            if( tmo_expired( &fsm->dmtd_timeout ) )
            {
                phy_dbg("[lpdc] TX phase measurement timeout, retrying...\n");
                fsm->state = TX_SETUP_STATE_RESET_PCS;
            }
            return 0;
        }

#ifdef LPDC_EXTRA_DEBUG
        phy_dbg("[lpdc] TX phase = %d ps, expected = %d, tollerance = %d\n", phase, fsm->expected_phase, fsm->tollerance );
#endif

        if (!fsm->expected_phase_valid)
        {
            if ( fsm->cal_saved_phase_valid )
            {
                if ( within_range( fsm->cal_saved_phase, LPDC_COARSE_PHASE_MIN_PS, LPDC_COARSE_PHASE_MAX_PS, 16000 ) )
                {
                    fsm->expected_phase = fsm->cal_saved_phase;
                    fsm->tollerance = LPDC_FINE_PHASE_TOLLERANCE_PS;
                    phy_dbg("[lpdc] Using the previous phase setpoint = %d ps as the target with tollerance = %d ps\n",
                            fsm->cal_saved_phase,
                            fsm->tollerance);
                } else {
                    fsm->expected_phase = (LPDC_COARSE_PHASE_MAX_PS + LPDC_COARSE_PHASE_MIN_PS) / 2;
                    fsm->tollerance = (LPDC_COARSE_PHASE_MAX_PS - LPDC_COARSE_PHASE_MIN_PS) / 2;
                    fsm->cal_saved_phase_valid = 0;
                    phy_dbg("[lpdc] Previous phase setpoint (%d ps) out of range. Old calibration algorithm? Restarting from scratch.\n", fsm->cal_saved_phase);
                }
            }
            else // find a sane default
            {
                fsm->expected_phase = (LPDC_COARSE_PHASE_MAX_PS + LPDC_COARSE_PHASE_MIN_PS) / 2;
                fsm->tollerance = (LPDC_COARSE_PHASE_MAX_PS - LPDC_COARSE_PHASE_MIN_PS) / 2;
                phy_dbg("[lpdc] No LPDC TX Calibration data found. Restarting from scratch.\n" );
            }
            fsm->expected_phase_valid = 1;
        }

        int phase_min = fsm->expected_phase - fsm->tollerance;
        int phase_max = fsm->expected_phase + fsm->tollerance;

        if (within_range(phase, phase_min, phase_max, 16000))
        {
            fsm->measured_phase = phase;
            fsm->tx_delta_correction = phase - fsm->cal_saved_phase;
            phy_dbg("[lpdc] Fix phase = %d ps, deltaTX correction = %d ps\n", fsm->measured_phase, fsm->tx_delta_correction );

            fsm->state = TX_SETUP_VALIDATE;
        }
        else
        {
            fsm->state = TX_SETUP_STATE_RESET_PCS;
        }

        break;
    }

    case TX_SETUP_VALIDATE:
    {
        phy_dbg("[lpdc] TX calibration complete (phase %d ps)\n", fsm->measured_phase);
        spll_enable_ptracker(0, 0);

        // enable the PCS+SFP on the port
        mdio_lpdc_write( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_TX_ENABLE | LPDC_MDIO_CTRL_DMTD_SOURCE_RXRECCLK );

        if( !fsm->cal_saved_phase_valid )
        {
            phy_dbg("[lpdc] Saving established target phase as calibration parameter: %d ps\n", fsm->measured_phase);
            storage_set_calibration_parameter_and_save( CAL_PARAM_PHY_TARGET_TX_PHASE, fsm->measured_phase);
        }

        fsm->state = TX_SETUP_DONE;
        break;
    }

    case TX_SETUP_DONE:
    {
        return 1;
        break;
    }
    }

    return 0;
}


static void rx_fsm_init(struct wrc_port_rx_setup_state* fsm)
{
	fsm->attempts = 0;
	fsm->state = RX_SETUP_STATE_INIT;
    fsm->prev_link_up = 0;
    memset(fsm->cpos_stat, 0, sizeof(fsm->cpos_stat ));
}


static void lpdc_read_pattern( struct wrc_lpdc_state *lpdc, uint16_t* data )
{
    int i;
 
    mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL2, LPDC_MDIO_CTRL2_RX_LATCH_PATTERN );

    for(i=0;i<LPDC_NUM_PATTERN_WORDS;i++)
    {
        data[i]  = mdio_lpdc_read( lpdc, LPDC_MDIO_IDLE_PAT + 4*i );
    }
}

static void reset_comma_histogram( struct comma_histogram *hist )
{
    memset(hist->bins, 0, sizeof(hist->bins) );
    hist->total_samples = 0;
}

static int update_comma_histogram( struct comma_histogram *hist, uint16_t *pattern )
{
    const uint16_t k28_5_minus = 0x283;

    int i, j;

    for(i=0;i<LPDC_NUM_COMMA_POSITIONS;i++)
    {
        int comma_found_plus = 1;
        int comma_found_minus = 1;
        //pp_printf("\n");
        for(j=0; j<10; j++)
        {
            int bit_index = i + j * LPDC_RX_OVERSAMPLE;
            int pbit = pattern[ bit_index >> 4 ] & ( 1<<(bit_index & 0xf)) ? 1 : 0;

            if( pbit && ! ( k28_5_minus&(1<<j) ) )
                comma_found_minus = 0;
            if( pbit &&   ( k28_5_minus&(1<<j) ) )
                comma_found_plus = 0;
            if( !pbit && ( k28_5_minus&(1<<j) ) )
                comma_found_minus = 0;
            if( !pbit && ! ( k28_5_minus&(1<<j) ) )
                comma_found_plus = 0;
          //  pp_printf("cbit %-2d %-2d %-2d p%d m%d\n",bit_index, bit_index >>4, bit_index & 0xf, pbit, k28_5_minus & (1<<j) ? 1:  0);
        }

        if( comma_found_plus || comma_found_minus )
        {
            //pp_printf("Found Comma [%c] @ %d\n", comma_found_minus ? '-' : '+', i);
            hist->bins[ i ]++;
            hist->total_samples++;
        }
    }

    return 0;
}

#define LPDC_HIST_COMMA_POS_OUT_OF_RANGE -2
#define LPDC_HIST_TOO_WIDE -1
#define LPDC_HIST_INSUFFICIENT_SAMPLES 0
#define LPDC_HIST_HIT 1

int check_histogram_threshold_hit(struct comma_histogram *hist, int threshold_samples, int border_discount_percent, int bins_filled, int target_comma_pos, int *comma_pos)
{
    int i;
    int max_bin_idx = 0, max_bin_value = 0;
    for (i = 0; i < LPDC_NUM_COMMA_POSITIONS; i++)
    {
        if (hist->bins[i] > max_bin_value)
        {
            max_bin_value = hist->bins[i];
            max_bin_idx = i;
        }
    }

    if (max_bin_value > 0 && abs(max_bin_idx - target_comma_pos) > bins_filled - 1)
    {
        *comma_pos = max_bin_idx;
        return LPDC_HIST_COMMA_POS_OUT_OF_RANGE;
    }

    if (max_bin_value < threshold_samples)
        return LPDC_HIST_INSUFFICIENT_SAMPLES;

    int thr_border = (100 - border_discount_percent) * max_bin_value / 1000;
    int low_idx = max_bin_idx, high_idx = max_bin_idx;

    while (low_idx > 0)
    {
        if (hist->bins[low_idx - 1] > thr_border)
            low_idx--;
        else
            break;
    }

    if (low_idx == 0 && hist->bins[LPDC_NUM_COMMA_POSITIONS - 1] > thr_border)
    {
        low_idx = LPDC_NUM_COMMA_POSITIONS - 1;
        while (low_idx > LPDC_NUM_COMMA_POSITIONS / 2)
        {
            if (hist->bins[low_idx - 1] > thr_border)
                low_idx--;
            else
                break;
        }

        if (low_idx == LPDC_NUM_COMMA_POSITIONS / 2)
            return LPDC_HIST_TOO_WIDE;
    }

    while (high_idx < LPDC_NUM_COMMA_POSITIONS - 1)
    {
        if (hist->bins[high_idx + 1] > thr_border)
            high_idx++;
        else
            break;
    }

    int n_bins = high_idx > low_idx ? high_idx - low_idx + 1 : LPDC_NUM_COMMA_POSITIONS + 1 + high_idx - low_idx;
    if (n_bins > bins_filled)
        return LPDC_HIST_TOO_WIDE;

    for (i = low_idx; i != high_idx; i = (i + 1) % LPDC_NUM_COMMA_POSITIONS)
        if (hist->bins[i] < threshold_samples)
            return LPDC_HIST_INSUFFICIENT_SAMPLES;

    *comma_pos = low_idx;

    if (low_idx == target_comma_pos)
        return LPDC_HIST_HIT;
    else
        return LPDC_HIST_COMMA_POS_OUT_OF_RANGE;
}

static int rx_fsm_update(struct wrc_lpdc_state *lpdc)
{
	struct wrc_port_rx_setup_state* fsm = &lpdc->rx_state;
	struct wrc_port_tx_setup_state* fsm_tx = &lpdc->tx_state;

    uint16_t lpc_stat = mdio_lpdc_read(lpdc, LPDC_MDIO_STAT);
    int early_link_up =  lpc_stat & LPDC_MDIO_STAT_LINK_UP;

	if( fsm_tx->state != TX_SETUP_DONE )
	{
		fsm->state = RX_SETUP_STATE_INIT;
		return 0;
	}

 	switch( fsm->state )
	{
		case RX_SETUP_STATE_INIT:
		{
            mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_RX_SW_RESET );
            mdio_lpdc_clear_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_RX_SW_RESET );
            mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL2, LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_RESET );
            mdio_lpdc_clear_bits( lpdc, LPDC_MDIO_CTRL2, LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_RESET );

            uint16_t ctrl2 = mdio_lpdc_read( lpdc,  LPDC_MDIO_CTRL2 );
            ctrl2 &= ~LPDC_MDIO_CTRL2_RX_RATE_MASK;
            mdio_lpdc_write( lpdc,  LPDC_MDIO_CTRL2, ctrl2 );

            fsm->state = RX_SETUP_STATE_CHECK_EARLY_LINK;
            break;
        }

        case RX_SETUP_STATE_CHECK_EARLY_LINK:
        {
            
            //pp_printf("lpdc_ctrl %x stat %x ctrl2 %x\n", ctrl, lpc_stat, ctrl2 );

            /*for(;;)
            {
                uint16_t ctrl2 = mdio_lpdc_read( lpdc,  LPDC_MDIO_CTRL2 );
                ctrl2 &= ~LPDC_MDIO_CTRL2_RX_RATE_MASK;
                ctrl2 |= 1;
                pp_printf("RXRATE = 1\n");
                mdio_lpdc_write( lpdc,  LPDC_MDIO_CTRL2, ctrl2 );
                timer_delay_ms(2000);

                ctrl2 &= ~LPDC_MDIO_CTRL2_RX_RATE_MASK;
                ctrl2 |= 2;
                pp_printf("RXRATE = 2\n");
                mdio_lpdc_write( lpdc,  LPDC_MDIO_CTRL2, ctrl2 );
                timer_delay_ms(2000);

                ctrl2 &= ~LPDC_MDIO_CTRL2_RX_RATE_MASK;
                ctrl2 |= 3;
                pp_printf("RXRATE = 3\n");
                mdio_lpdc_write( lpdc,  LPDC_MDIO_CTRL2, ctrl2 );
                timer_delay_ms(2000);


                ctrl2 &= ~LPDC_MDIO_CTRL2_RX_RATE_MASK;
                ctrl2 |= 4;
                pp_printf("RXRATE = 4\n");
                mdio_lpdc_write( lpdc,  LPDC_MDIO_CTRL2, ctrl2 );
s                timer_delay_ms(2000);

            }*/

            //mdio_lpdc_clear_bits( )

	        if (early_link_up) {
				phy_dbg("[lpdc] RX calibration started.\n");
	
				fsm->state = RX_SETUP_STATE_RESET_PCS;
			}

			fsm->attempts = 0;

			break;
		}

		case RX_SETUP_STATE_RESET_PCS:
		{
            reset_comma_histogram( &fsm->comma_hist );

            mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_RX_SW_RESET );
            mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL2, LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_RESET );
            mdio_lpdc_clear_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_RX_SW_RESET );

            tmo_init(&fsm->link_timeout, 100);

            fsm->state = RX_SETUP_STATE_WAIT_RX_RESET_DONE;
            break;
        }

        case RX_SETUP_STATE_WAIT_RX_RESET_DONE:
        {
            uint16_t ctrl2 = mdio_lpdc_read( lpdc, LPDC_MDIO_CTRL2 );
            if( (lpc_stat & LPDC_MDIO_STAT_RX_RST_DONE ) && ( ctrl2 & LPDC_MDIO_CTRL2_RX_CDR_LOCKED ) )
            {
                mdio_lpdc_clear_bits( lpdc, LPDC_MDIO_CTRL2, LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_RESET );
                fsm->state = RX_SETUP_STATE_WAIT_GEARBOX_PLL_LOCKED;
            } else if (tmo_expired( &fsm->link_timeout ))
            {
                phy_dbg("[lpdc] timeout waiting for rx reset done\n");
                fsm->state = RX_SETUP_STATE_RESET_PCS;
            }
            break;
        }
            
        case RX_SETUP_STATE_WAIT_GEARBOX_PLL_LOCKED:
        {
            uint16_t ctrl2 = mdio_lpdc_read( lpdc, LPDC_MDIO_CTRL2 );
            if( ctrl2 & LPDC_MDIO_CTRL2_RX_GEARBOX_PLL_LOCKED )
            {
                fsm->state = RX_SETUP_STATE_BUILD_COMMA_HISTOGRAM;
            }else if (tmo_expired( &fsm->link_timeout ))
            {
                phy_dbg("[lpdc] timeout waiting for rx gearbox PLL\n");
                fsm->state = RX_SETUP_STATE_RESET_PCS;
            }
            break;
        }

        case RX_SETUP_STATE_BUILD_COMMA_HISTOGRAM:
        {
            uint16_t pattern[LPDC_NUM_PATTERN_WORDS];
            lpdc_read_pattern( lpdc, pattern );

            //paattern0000f0fffff0000f0fff00ff00f0ff
#if 0
            pattern[7] = 0xe0;
            pattern[6] = 0x1fff;
            pattern[5] = 0xe01e;
            pattern[4] = 0x1e1e;
            pattern[3] = 0x1e1e;
            pattern[2] = 0x1fe1;
            pattern[1] = 0xe000;
            pattern[0] = 0x01ff;

            pp_printf("latched pattern: ");
            for(i=LPDC_NUM_PATTERN_WORDS-1; i>=0; i--)
            {
                if(i==LPDC_NUM_PATTERN_WORDS-1) // pattern is 120 bits
                    pp_printf("%02x", pattern[i] & 0xff);
                else
                    pp_printf("%04x", pattern[i] & 0xffff);
            }
            pp_printf("\n");
#endif
            update_comma_histogram( &fsm->comma_hist, pattern );

            
            int comma_pos;
            int status = check_histogram_threshold_hit( &fsm->comma_hist, 50, 10, 4, LPDC_TARGET_COMMA_POS, &comma_pos );

            switch( status )
            {
            case LPDC_HIST_COMMA_POS_OUT_OF_RANGE:
#ifdef LPDC_EXTRA_DEBUG
                pp_printf("[lpdc] Comma @ %d (miss)\n", comma_pos);
#endif
                fsm->state = RX_SETUP_STATE_RESET_PCS;
                break;
            case LPDC_HIST_HIT:
            {
                int i;
#ifdef LPDC_EXTRA_DEBUG
                pp_printf("Comma @ %d (hit)\n", comma_pos);
                pp_printf("latched pattern: ");
                for (i = LPDC_NUM_PATTERN_WORDS - 1; i >= 0; i--)
                {
                if (i == LPDC_NUM_PATTERN_WORDS - 1) // pattern is 120 bits
                    pp_printf("%02x", pattern[i] & 0xff);
                else
                    pp_printf("%04x", pattern[i] & 0xffff);
                }
                pp_printf("\n");
                pp_printf("histogram: ");
                for (i = 0; i < LPDC_NUM_COMMA_POSITIONS; i++)
                pp_printf("%d ", fsm->comma_hist.bins[i]);
                pp_printf("\n");
#endif

                fsm->state = RX_SETUP_STATE_MEASURE_PHASE;
                break;
            }
            case LPDC_HIST_TOO_WIDE:
            {
                int i;
#ifdef LPDC_EXTRA_DEBUG
                pp_printf("Too wide: ");
                for (i = 0; i < LPDC_NUM_COMMA_POSITIONS; i++)
                {
                if (fsm->comma_hist.bins[i])
                    pp_printf("%-2d:%-4d ", i, fsm->comma_hist.bins[i]);
                }

                pp_printf("\n");
#endif
                fsm->state = RX_SETUP_STATE_RESET_PCS;
                break;
            }
            default:
                break;
            }

            if (!early_link_up)
            {
                fsm->state = RX_SETUP_STATE_INIT;
            }
            break;
        }


        case RX_SETUP_STATE_MEASURE_PHASE:
        {
            uint16_t ctrl = mdio_lpdc_read( lpdc, LPDC_MDIO_CTRL );
            
            ctrl &= ~LPDC_MDIO_CTRL_DMTD_CLK_SEL_MASK;
            ctrl |= LPDC_MDIO_CTRL_DMTD_SOURCE_RXRECCLK;
            ctrl |= LPDC_MDIO_CTRL_RX_ENABLE;
            ctrl |= LPDC_MDIO_CTRL_TX_ENABLE;

            mdio_lpdc_write( lpdc, LPDC_MDIO_CTRL, ctrl );

            sfp_info.sfp_params.dRx = 1000 + 0;
            sfp_info.sfp_params.dTx = 1000 + fsm_tx->tx_delta_correction;

            ep_sfp_enable( lpdc->endpoint, 1 );
	        ep_pcs_write(lpdc->endpoint,  EP_MDIO_MCR, EP_MDIO_MCR_SPEED1000 | EP_MDIO_MCR_FULLDPLX | EP_MDIO_MCR_ANENABLE | EP_MDIO_MCR_ANRESTART  );
            fsm->state = RX_SETUP_DONE;
            phy_dbg("[lpdc] RX Calibration Done!\n");

            //mdio_lpdc_set_bits( lpdc, LPDC_MDIO_CTRL, LPDC_MDIO_CTRL_RX_ENABLE );
            break;
        }

        case RX_SETUP_DONE:
        break;

        default:
        break;
    }


	return 0;
}

static struct wrc_lpdc_state lpdc;

int phy_calibration_poll(void)
{
    tx_fsm_update(&lpdc);
    rx_fsm_update(&lpdc);
    return 1;
}




void phy_calibration_init(void)
{
    // fixme: do we want more than one in the WRC? maybe soon...
    lpdc.endpoint = &wrc_endpoint_dev;

    phy_dbg("[lpdc] Initializing PHY calibrator...\n");
    
    ep_pcs_write(lpdc.endpoint, EP_MDIO_MCR, EP_MDIO_MCR_PDOWN);	/* reset the PHY */
	timer_delay_ms(200);
	ep_pcs_write(lpdc.endpoint, EP_MDIO_MCR, EP_MDIO_MCR_RESET);	/* reset the PHY */
	ep_pcs_write(lpdc.endpoint, EP_MDIO_MCR, 0);	/* reset the PHY */

    mdio_lpdc_write( &lpdc, LPDC_MDIO_CTRL, 0 );
    mdio_lpdc_write( &lpdc, LPDC_MDIO_CTRL2, 0 );

    tx_fsm_init(&lpdc.tx_state);
    rx_fsm_init(&lpdc.rx_state);
}

void phy_calibration_disable(void)
{
    lpdc.tx_state.state = TX_SETUP_STATE_DISABLED;
    lpdc.rx_state.state = RX_SETUP_STATE_DISABLED;
}
