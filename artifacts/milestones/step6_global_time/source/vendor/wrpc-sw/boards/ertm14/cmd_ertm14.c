/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2012 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <wrc.h>

#include "board.h"
#include "dev/clock_monitor.h"
#include "dev/console.h"
#include "softpll_ng.h"
#include "shell.h"

#include "ertm15_rf_distr.h"
#include "board-aux.h"

extern struct wb_clock_monitor_device ertm14_cmon;

const char* clock_names[] = { "clk_dmtd", "clk_sys", "clk_tx1", "clk_tx2", "clk_rx" };

static const char *get_rf_out_state_string(int state)
{
    switch(state)
    {
        case ERTM15_RF_OUT_ON: return "ON";
        case ERTM15_RF_OUT_OFF: return "OFF";
        case ERTM15_RF_OUT_MONITOR: return "MONITOR";
    }
    return "";
}


static void dump_dds_state( const char *name, struct ertm14_dds_state *cfg ) 
{
    int i;
    uint64_t freq = ad9910_ftw_to_frequency( cfg->ftw );

    pp_printf("%s DDS FTW:                0x%08x (%d Hz)\n",
	      name, (unsigned) cfg->ftw, (unsigned) freq );
    pp_printf("%s DDS amplitude factor:   %d\n", name, cfg->ampl_factor);
    pp_printf("%s DDS measured power:     %d.%02d dBm\n", name, cfg->amp_power / 1000, cfg->amp_power % 1000);
    pp_printf("%s outputs:\n", name);
    for( i = ERTM14_RF_OUT_MIN_ID; i <= ERTM14_RF_OUT_MAX_ID; i++ )
        pp_printf("- %s%d: %8s (last measured power = %d.%02d dBm)\n", name, i, get_rf_out_state_string( cfg->out_state[i] ),
        cfg->out_power[i] / 1000, cfg->out_power[i] % 1000
        );
}

static void dump_config( struct ertm14_board_state *cfg )
{
    int i = 0;

    dump_dds_state("LO", &cfg->lo);
    dump_dds_state("REF", &cfg->ref);

    pp_printf("CLKA/CLKB outputs: \n");
    for(i = 0; i <= ERTM14_CLKAB_OUT_MAX_ID; i++)
    {
        pp_printf(" - CLKA%02d: %-20d Hz (%s) CLKB%02d: %-20d Hz (%s)\n",
	i, (unsigned)cfg->clka_freq_hz[i], (cfg->clka_enable_mask & (1<<i)) ? "ON " : "OFF",
        i, (unsigned)cfg->clkb_freq_hz[i], (cfg->clkb_enable_mask & (1<<i)) ? "ON " : "OFF" );
    }
}

#define PARAM_FTW 0
#define PARAM_AMPL 1
#define PARAM_ENABLE 2
#define PARAM_FREQ 3

static void set_dds_param(struct ertm14_board_state *cfg, struct ertm14_board_state* mask, int param, const char *name, const char *value, const char *value2)
{
    if( !name || !value )
    {
        pp_printf("Too few arguments.\n");
        return;
    }

    int is_lo = !strcasecmp( name , "lo");
    int is_ref = !strcasecmp( name , "ref");

    if(is_lo || is_ref)
    {
        struct ertm14_dds_state *dcfg = is_lo ? &cfg->lo : &cfg->ref;
        struct ertm14_dds_state *dmask = is_lo ? &mask->lo : &mask->ref;

        switch(param)
        {
            case PARAM_AMPL:
                dcfg->ampl_factor = strtol(value, NULL, 0);
                dmask->ampl_factor = 1;
                break;
            case PARAM_FTW:
                dcfg->ftw = strtol(value, NULL, 0);
                dmask->ftw = 1;
                break;
            case PARAM_ENABLE:
            {
                 int out = atoi(value);
                 if( out >= ERTM14_RF_OUT_MIN_ID && out <= ERTM14_RF_OUT_MAX_ID )
                 {
                     pp_printf("DDS %s is %s\n", is_lo?"LO":"REF", atoi(value2)?"ON":"OFF" );
                    dcfg->out_state[out] = atoi(value2) ? ERTM15_RF_OUT_ON : ERTM15_RF_OUT_OFF;
                     dmask->out_state[out] = 1;
                 }
                 else
                 {
                     pp_printf("Expected LO/REF output index\n");
                 }
                 break;
            }
            default:
            break;
        }
    }
    else
    {
        pp_printf("Expected DDS channel name: [lo,ref]\n");
    }
}

static void set_clk_param(struct ertm14_board_state *cfg, struct ertm14_board_state* mask, int param, const char *name, const char *channel, const char *value)
{
    int is_clka = !strcasecmp( name , "clka");
    int is_clkb = !strcasecmp( name , "clkb");
    
    if (is_clka || is_clkb)
    {
        uint32_t *freq = is_clka ? cfg->clka_freq_hz : cfg->clkb_freq_hz;
        uint32_t *enable_flag = is_clka ? &cfg->clka_enable_mask : &cfg->clkb_enable_mask;

        uint32_t *freq_mask = is_clka ? mask->clka_freq_hz : mask->clkb_freq_hz;
        uint32_t *enable_flag_mask = is_clka ? &mask->clka_enable_mask : &mask->clkb_enable_mask;
        
        int ch = atoi(channel);

        switch(param)
        {
            case PARAM_FREQ:
                freq[ch] = atoi(value);
                freq_mask[ch] = 1;
            break;
            case PARAM_ENABLE:
            {
                *enable_flag_mask |= (1<<ch);
              if(atoi(value))
                    *enable_flag |= (1<<ch);
            else
                    *enable_flag &= ~(1<<ch);

                break;
            }
            default: break;
        }

    }
    else
    {
        pp_printf("Expected CLK name: clka clkb\n");
}
}

static void set_streamers_timeout(struct ertm14_board_state *cfg, struct ertm14_board_state* mask, int param )
{
    cfg->streamers_timeout_cycles = param;
    mask->streamers_timeout_cycles = 1;
}

static void set_streamers_latency(struct ertm14_board_state *cfg, struct ertm14_board_state* mask, int param )
{
    cfg->streamers_latency_cycles = param;
    mask->streamers_latency_cycles = 1;
}

static void ertm_test_dac(void)
{
    int i = 0;
    pp_printf("Playing sawtooth on eRTM15 OCXO DAC. Press ESC to abort.\n");

    for (;;)
    {
        int c = console_getc();

        if (c == 0x1b)
            break;

        spll_set_dac(0, i & 0xffff);

        i += 100;

        timer_delay(5);
    }
}

static void set_dds_sync_source( struct ertm14_board_state *cfg, struct ertm14_board_state* mask, const char *channel_name, const char *src_name )
{

}

static void set_pps_mode(const char *mode )
{
    if(!mode)
    {
        pp_printf("PPS mode expected\n");
        return;
    }

    int m = atoi(mode);

    pp_printf("Setting PPS output mode to: %d\n", m);

    ertm14_set_pps_out_mode( m );
}

static void ertm14_dna_cmd(void)
{
	volatile unsigned *dna = (volatile unsigned *)BASE_ERTM14_DNA;

	pp_printf("--buildinfo--\n");
	pp_printf("%s", (const char *)BASE_ERTM14_BUILD_INFO);
	pp_printf("--dna--\n");
	if (!(dna[0] & 1))
		pp_printf ("not valid\n");
	else {
		unsigned i;
		for (i = 1; i < 4; i++)
			pp_printf("%08x\n", dna[i]);
	}
}

/* FIXME: this should be in a .h file */
extern void phy_calibration_disable(void);
extern void streamers_reset_rx_stats(void);
extern int streamers_get_rx_latency(void);
extern int streamers_get_rx_timeout(void);

static int cmd_ertm(const char *args[])
{
    struct ertm14_board_state *cstate = ertm14_get_current_state();
    struct ertm14_board_state mask, nstate;

    memset(&nstate, 0, sizeof(struct ertm14_board_state ) );
    memset(&mask, 0, sizeof(struct ertm14_board_state ) );

    if (!strcasecmp(args[0], "test-dac")) 
    {
        ertm_test_dac();
    } else if (!strcasecmp(args[0], "show-config") ) {
        dump_config( cstate );
    } else if (!strcasecmp(args[0], "set-dds-ftw")) {
        set_dds_param( &nstate, &mask, PARAM_FTW, args[1], args[2], args[3] );
    } else if (!strcasecmp(args[0], "set-dds-ampl")) {
        set_dds_param( &nstate, &mask, PARAM_AMPL, args[1], args[2], 0 );
    } else if (!strcasecmp(args[0], "set-dds-enable")) {
        set_dds_param( &nstate, &mask, PARAM_ENABLE, args[1], args[2], args[3]);
    } else if (!strcasecmp(args[0], "set-clk-enable")) {
        set_clk_param( &nstate, &mask, PARAM_ENABLE, args[1], args[2], args[3]);
    } else if (!strcasecmp(args[0], "set-clk-freq")) {
        set_clk_param( &nstate, &mask, PARAM_FREQ, args[1], args[2] ,args[3]);
    } else if (!strcasecmp(args[0], "set-dds-sync-source")) {
        set_dds_sync_source( &nstate, &mask, args[1], args[2]);
    } else if (!strcasecmp(args[0], "set-streamers-latency")) {
        set_streamers_latency( &nstate, &mask, strtol(args[1], NULL, 0) );
    } else if (!strcasecmp(args[0], "set-streamers-timeout")) {
        set_streamers_timeout( &nstate, &mask, strtol(args[1], NULL, 0) );
    } else if (!strcasecmp(args[0], "reset-stats")) {
        streamers_reset_rx_stats();
    } else if (!strcasecmp(args[0], "pps-mode")) {
        set_pps_mode( args[1] );
    } else if (!strcasecmp(args[0], "ccal")) {
        ertm14_sync_pulse_cal(  );
    } else if (!strcasecmp(args[0], "dna")) {
        ertm14_dna_cmd(  );
    }
    ertm14_apply_config( &nstate, &mask, 0 );
    update_config( cstate, &nstate, &mask );

    return 0;
}

#define ERTM14_MON_REFRESH_PERIOD 1000 // ms

static timeout_t ertm14_mon_timer;

static const char *nco_sync_source_to_string(int src)
{
    switch(src)
    {
        case ERTM14_SYNC_SOURCE_NONE: return "Off";
        case ERTM14_SYNC_SOURCE_PPS: return "PPS";
        case ERTM14_SYNC_SOURCE_RF_TRIGGER: return "RF Trigger";
        default: return "?";
    }
}


static int ertm14_monitor_ui(void)
{
    if( !tmo_expired( &ertm14_mon_timer ))
        return 0;

    uint32_t ret;
    uint32_t rx_count, rx_lat_min, rx_lat_max, rx_match, rx_late, rx_timeout;

    tmo_restart( &ertm14_mon_timer );

    term_clear();

	cprintf(C_BLUE, "eRTM14/15 Board Monitor");
	cprintf(C_GREY, "\nEsc = exit\n\n");

    ret = diag_read_word(8, DIAG_RO_BANK, &rx_count);
    ret = diag_read_word(4, DIAG_RO_BANK, &rx_lat_max);
    ret = diag_read_word(5, DIAG_RO_BANK, &rx_lat_min);
    ret = diag_read_word(20, DIAG_RO_BANK, &rx_match);
    ret = diag_read_word(22, DIAG_RO_BANK, &rx_late);
    ret = diag_read_word(24, DIAG_RO_BANK, &rx_timeout);

    (void) ret;
    
    struct ertm14_board_state *st = ertm14_get_current_state();

    if(!st)
        return 0;

    cprintf(C_GREY, "Streamers status: \n");
    cprintf(C_GREY, "RX Packets:                ");
    cprintf(C_WHITE, "%d\n", rx_count);
    cprintf(C_GREY, "RX Latency:                ");
    cprintf(C_WHITE, "min: %d, max: %d (cycles)\n", rx_lat_min, rx_lat_max);
    cprintf(C_GREY, "RX Matches:                ");
    cprintf(C_WHITE, "%d\n", rx_match);
    cprintf(C_GREY, "RX Late:                   ");
    cprintf(C_WHITE, "%d\n", rx_late);
    cprintf(C_GREY, "RX Timeout:                ");
    cprintf(C_WHITE, "%d\n", rx_timeout);
    cprintf(C_GREY, "RX Config Latency:         ");
    cprintf(C_WHITE, "%d\n", streamers_get_rx_latency() );
    cprintf(C_GREY, "RX Config Timeout:         ");
    cprintf(C_WHITE, "%d\n", streamers_get_rx_timeout() );
    
    cprintf(C_GREY, "\nNCO Reset status: \n");
    cprintf(C_GREY, "LO DDS Reset Mode:         ");
    cprintf(C_WHITE, "%s\n", nco_sync_source_to_string(st->lo.sync_source));
    cprintf(C_GREY, "REF DDS Reset Mode:        ");
    cprintf(C_WHITE, "%s\n", nco_sync_source_to_string(st->ref.sync_source));
    cprintf(C_GREY, "LO DDS Resets:             ");
    cprintf(C_WHITE, "%d\n", st->lo.sync_count);
    cprintf(C_GREY, "REF DDS Resets:            ");
    cprintf(C_WHITE, "%d\n", st->ref.sync_count);



    return 0;
}

static int cmd_ertm_ui(const char *args[])
{
    tmo_init( &ertm14_mon_timer, ERTM14_MON_REFRESH_PERIOD );
	shell_activate_ui_command( ertm14_monitor_ui );
	return 0;
}

DEFINE_WRC_COMMAND(ertm) = {
	.name = "ertm",
	.exec = cmd_ertm,
};

DEFINE_WRC_COMMAND(ertm_ui) = {
	.name = "eu", // fixme
	.exec = cmd_ertm_ui,
};

void ertm14_shell_init()
{
    shell_register_command( &__wrc_cmd_ertm );
    shell_register_command( &__wrc_cmd_ertm_ui );
}
