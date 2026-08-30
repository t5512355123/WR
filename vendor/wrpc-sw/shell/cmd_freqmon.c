/*
 * This work is part of the White Rabbit project
 *
 * Copyright (C) 2023 CERN (www.cern.ch)
 * Author: Tomasz Wlostowski <tomasz.wlostowski@cern.ch>
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include "wrpc.h"

#include "board.h"

#include "dev/console.h"
#include "dev/clock_monitor.h"

#include "softpll_ng.h"
#include "shell.h"

#ifdef CONFIG_FREQUENCY_MONITOR

#define CM_CHANNEL_SYS 0
#define CM_CHANNEL_DMTD 1
#define CM_CHANNEL_REF 2
#define CM_CHANNEL_RX 3

#define CM_DEFAULT_GATE_FREQ 5000000
#define CM_DEFAULT_PRESCALER 5

static struct wb_clock_monitor_device cmon_dev;
static uint8_t cmon_initialized = 0;
static uint8_t cmon_ref_is_rx = 0;

struct cm_clock_desc
{
    const char *name;
    uint8_t is_tunable;
    int8_t dac_index;
};

static int cm_get_clock_desc(int idx, struct cm_clock_desc *desc)
{
    static const char *auxes[] = {"AUX0", "AUX1", "AUX2", "AUX3"};
    switch (idx)
    {
    case 0:
        desc->name = "SYS";
        desc->is_tunable = 0;
        return 0;
    case 1:
        desc->name = "DMTD";
        desc->is_tunable = 1;
        desc->dac_index = -1;
        return 0;
    case 2:
        desc->name = "REF";
        desc->is_tunable = 1;
        desc->dac_index = 0;
        return 0;
    case 3:
        desc->name = "RX";
        desc->is_tunable = 0;
        desc->dac_index = 0;
        return 0;
    default:
    {
        int n_ref, n_out;
        spll_get_num_channels(&n_ref, &n_out);
        if (n_out > 1 && idx - 3 < n_out)
        {
            desc->name = auxes[idx - 4];
            desc->is_tunable = 1;
            desc->dac_index = idx - 4 + 1;
            return 0;
        }
        else if (idx == 4 + n_out - 1 && spll_is_ext_supported())
        {
            desc->name = "EXT";
            desc->is_tunable = 0;
            desc->dac_index = 0;
            return 0;
        }
        break;
    }
    }

    return -ENODEV;
}

static int cm_get_clock_count(void)
{
    struct cm_clock_desc desc;
    int i;
    for (i = 0; cm_get_clock_desc(i, &desc) >= 0; i++)
        ;
    return i;
}

static void cmon_init(void)
{
    int n_clks = cm_get_clock_count();
    wb_cm_init(&cmon_dev, BASE_CLOCK_MONITOR, n_clks);
    wb_cm_set_ref_frequency(&cmon_dev, REF_CLOCK_FREQ_HZ);
    wb_cm_configure(&cmon_dev, cmon_ref_is_rx ? CM_CHANNEL_RX : CM_CHANNEL_REF, CM_DEFAULT_PRESCALER, CM_DEFAULT_GATE_FREQ);
    wb_cm_restart(&cmon_dev);
    pp_printf("CMON initialized\n");
}

static void cmon_update(void)
{
    if (!cmon_initialized)
    {
        cmon_init();
        cmon_initialized = 1;
    }

    wb_cm_read(&cmon_dev);
}

static int calc_apr(int meas_min, int meas_max, int f_center)
{
    // apr_min is in PPM

    if (f_center < meas_min || f_center > meas_max)
        f_center = (meas_min + meas_max) / 2;

    int64_t delta_low = meas_min - f_center;
    int64_t delta_hi = meas_max - f_center;
    uint64_t u_delta_low, u_delta_hi;
    int ppm_lo, ppm_hi;

    if (delta_low >= 0)
        return -1;
    if (delta_hi <= 0)
        return -1;

    /* __div64_32 divides 64 by 32; result is in the 64 argument. */
    u_delta_low = -delta_low * 1000000000LL;
    __div64_32(&u_delta_low, f_center);
    ppm_lo = (int)u_delta_low;

    u_delta_hi = delta_hi * 1000000000LL;
    __div64_32(&u_delta_hi, f_center);
    ppm_hi = (int)u_delta_hi;

    return ppm_lo < ppm_hi ? ppm_lo : ppm_hi;
}

typedef void (*dac_setter_t)(int, int);

struct cm_vco_stats
{
    int f_min, f_max, f_center;
    int apr_ppb;
};

static int measure_vcxo_freq(int cm_channel, int n_steps, uint32_t expected_freq, int dac_index, dac_setter_t dac_setter, struct cm_vco_stats *stats)
{
    int f_min = 0, f_max = 0;
    int tune_min = 0;
    int tune_max = 65535;
    int tune_step = (tune_max - tune_min) / n_steps;

    int tune = tune_min;

    for (;;)
    {

        dac_setter(dac_index, tune);
        timer_delay_ms(100);
        wb_cm_restart(&cmon_dev);

        while (!(wb_cm_read(&cmon_dev) & (1 << cm_channel)))
        {
            if (console_getc() == 0x1b) // esc pressed
                return -EAGAIN;
        }

        int f = cmon_dev.freqs[cm_channel];

        if (tune == tune_min)
            f_min = f;
        else if (tune == tune_max)
            f_max = f;

        if (tune == tune_max)
            break;

        pp_printf(" - DAC value=%d, f=%d Hz, delta_f=%d Hz\n",
		  tune, f, (int)(f - expected_freq));

        tune += tune_step;
        if (tune > tune_max)
            tune = tune_max;
    }

    dac_setter(dac_index, 32768);
    timer_delay(1);

    int l_apr = calc_apr(f_min, f_max, expected_freq);

    if (stats)
    {
        stats->apr_ppb = l_apr;
        stats->f_center = (f_min + f_max) / 2;
        stats->f_min = f_min;
        stats->f_max = f_max;
    }

    return 0;
}

static void dac_setter(int index, int value)
{
    // pp_printf("sdac %d %d\n", index, value );
    spll_set_dac(index, value);
}

void cm_show_clocks(void)
{
    int i;
    struct cm_clock_desc desc;

    cmon_update();

    pp_printf("Reference clock for frequency measurement: %s\n", cmon_ref_is_rx ? "RX" : "REF");
    for (i = 0; cm_get_clock_desc(i, &desc) >= 0; i++)
    {
        char freq_str[32];

        if (cmon_dev.freq_valid_mask & (1 << i))
            pp_sprintf(freq_str, "%-12u", cmon_dev.freqs[i]);
        else
            strcpy(freq_str, "UNKNOWN");

        pp_printf("Channel %d: %-6s tunable=%d, freq=%s Hz\n", i, desc.name, desc.is_tunable, freq_str);
    }
}

int cm_check_vcos(const char *args[])
{
    int n_steps = 2;
    struct cm_clock_desc desc;
    int i;

    if (args[1])
        n_steps = atoi(args[1]);

    if (!cmon_initialized)
        cmon_init();

    pp_printf("Checking VCOs. Note: the board must have its uplink connected to a stable frequency reference. Press ESC to abort anytime.\n");

    wrc_ptp_run(0);
	wrpc_spll_note_init_reason(WRPC_SPLL_INIT_REASON_FREQMON,
				SPLL_MODE_DISABLED, 0);
    spll_init(SPLL_MODE_DISABLED, 0, 0);

    wb_cm_configure(&cmon_dev, CM_CHANNEL_RX, CM_DEFAULT_PRESCALER, CM_DEFAULT_GATE_FREQ);
    wb_cm_restart(&cmon_dev);

    for (i = 0; cm_get_clock_desc(i, &desc) >= 0; i++)
    {
        struct cm_vco_stats stats;
        if (!desc.is_tunable)
            continue;

        // fixme: ref
        int r = measure_vcxo_freq(i, n_steps, REF_CLOCK_FREQ_HZ, desc.dac_index, dac_setter, &stats);
        if (r < 0)
            return 0;

        pp_printf("VCO: %-6s: f_min=%d Hz, f_max=%d Hz, f_center=%d Hz, APR=%d ppb\n",
                  desc.name,
                  stats.f_min,
                  stats.f_max,
                  stats.f_center,
                  stats.apr_ppb);
    }

    //    measure_vcxo_freq( ERTM14_CMON_CLK_REF, ERTM14_CMON_CLK_DMTD, 10000000, 1, 62500000, set_main_dac, NULL, NULL );
    //  board_dbg("Check DMTD VCXO\n");
    //    measure_vcxo_freq( ERTM14_CMON_CLK_DMTD, ERTM14_CMON_CLK_REF, 100000, 10, 62500000, set_dmtd_dac, NULL, NULL );
    return 0;
}

static int cmd_freqmon(const char *args[])
{
    if (!args[0])
    {
        cm_show_clocks();
    }
    else if (!strcasecmp(args[0], "checkvco"))
    {
        cm_check_vcos(args);
    }
    else if (!strcasecmp(args[0], "rx"))
    {
        cmon_ref_is_rx = 1;
        cmon_init();
    }
    else if (!strcasecmp(args[0], "ref"))
    {
        cmon_ref_is_rx = 0;
        cmon_init();
    }

    return 0;
}

DEFINE_WRC_COMMAND(freqmon) = {
    .name = "freqmon",
    .exec = cmd_freqmon,
};

#endif
