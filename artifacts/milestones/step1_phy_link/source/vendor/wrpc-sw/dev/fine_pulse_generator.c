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

/* Driver for Fine Pulse Generator unit */

#include <string.h>

#include "board.h"
#include "hw/rawmem.h"
#include "wrc-debug.h"
#include "dev/syscon.h"

#include "hw/wb_fpgen_regs.h"
#include "dev/fine_pulse_generator.h"

#undef FPGEN_EXTRA_VERBOSE

#define FPG_CSR_FORCE0_OFFSET 8 // fixme

static inline void fpgen_writel(struct fine_pulse_gen_device *dev, uint32_t data, uint32_t reg)
{
    writel(data, dev->base + reg);
}

static inline uint32_t fpgen_readl(struct fine_pulse_gen_device *dev, uint32_t reg)
{
    uint32_t rv = readl(dev->base + reg);
    return rv;
}

static void fine_pulse_gen_calibrate_taps_kintexu(struct fine_pulse_gen_device *dev) // ultrascale only
{
    int i;

    fpgen_writel(dev, 0, WB_FPGEN_ODELAY_CALIB);
    usleep(1000);
    fpgen_writel(dev, WB_FPGEN_ODELAY_CALIB_EN_VTC, WB_FPGEN_ODELAY_CALIB);
    usleep(1000);

    fpgen_writel(dev, WB_FPGEN_ODELAY_CALIB_RST_IDELAYCTRL | WB_FPGEN_ODELAY_CALIB_RST_ODELAY | WB_FPGEN_ODELAY_CALIB_RST_OSERDES, WB_FPGEN_ODELAY_CALIB);
    usleep(10);
    fpgen_writel(dev, WB_FPGEN_ODELAY_CALIB_RST_IDELAYCTRL | WB_FPGEN_ODELAY_CALIB_RST_OSERDES, WB_FPGEN_ODELAY_CALIB);
    usleep(10);

    fpgen_writel(dev, WB_FPGEN_ODELAY_CALIB_RST_IDELAYCTRL, WB_FPGEN_ODELAY_CALIB);
    usleep(10);

    fpgen_writel(dev, 0, WB_FPGEN_ODELAY_CALIB);
    usleep(10);

    while ((fpgen_readl(dev, WB_FPGEN_ODELAY_CALIB) & WB_FPGEN_ODELAY_CALIB_RDY) == 0)
        usleep(1);

    usleep(10000);

    fpgen_writel(dev, 0, WB_FPGEN_ODELAY_CALIB);
    fpgen_writel(dev, WB_FPGEN_ODELAY_CALIB_CAL_LATCH, WB_FPGEN_ODELAY_CALIB);

    uint32_t rv = fpgen_readl(dev, WB_FPGEN_ODELAY_CALIB);

    int calib_taps = (rv & WB_FPGEN_ODELAY_CALIB_TAPS_MASK) >> WB_FPGEN_ODELAY_CALIB_TAPS_SHIFT;

    for (i = 0; i < FINE_PULSE_GEN_MAX_CHANNELS; i++)
    {
        dev->channels[i].delay_tap_size_ps = dev->serdes_bit_length_ps / calib_taps;
    }
}

void fine_pulse_gen_reset(struct fine_pulse_gen_device *dev)
{
    fpgen_writel(dev, WB_FPGEN_CSR_PLL_RST | WB_FPGEN_CSR_SERDES_RST, WB_FPGEN_CSR); // reset pll
    usleep(1);
    fpgen_writel(dev, WB_FPGEN_CSR_SERDES_RST, WB_FPGEN_CSR); // unreset pll, keep serdes in reset until PLL locked

    do
    {
        usleep(10);
    } while (!(fpgen_readl(dev, WB_FPGEN_CSR) & WB_FPGEN_CSR_PLL_LOCKED));

    fpgen_writel(dev, 0, WB_FPGEN_CSR); // PLL locked? release serdes reset

    fpgen_writel(dev, WB_FPGEN_ODELAY_CALIB_RST_IDELAYCTRL, WB_FPGEN_ODELAY_CALIB); // reset idelayctrl
    usleep(1);
    fpgen_writel(dev, 0, WB_FPGEN_ODELAY_CALIB); // un-reset idelayctrl

    do
    {
        usleep(1);
    } while (!(fpgen_readl(dev, WB_FPGEN_ODELAY_CALIB) & WB_FPGEN_ODELAY_CALIB_RDY));

    fpgen_writel(dev, 0, WB_FPGEN_CSR); // PLL locked? release serdes reset

    if (dev->calibrate_fine_delay)
        fine_pulse_gen_calibrate_taps_kintexu(dev);
}

int fine_pulse_gen_init(struct fine_pulse_gen_device *dev, void *base, uint32_t target)
{
    int i;
    int delay_tap_size_ps = 78;

    memset(dev, 0, sizeof(struct fine_pulse_gen_device));
    dev->base = base;

    switch (target)
    {
    case FINE_PULSE_GEN_TARGET_KINTEXU:
        dev->serdes_ratio = 16;
        dev->serdes_bit_length_ps = 1000;
        dev->calibrate_fine_delay = 1;
        break;
    case FINE_PULSE_GEN_TARGET_KINTEX7:
        dev->calibrate_fine_delay = 0;
        dev->serdes_ratio = 8;
        dev->serdes_bit_length_ps = 2000;
        delay_tap_size_ps = 78; // guaranteed by IDELAYCTRL @ 200 MHz refclk
        break;
    default:
        return -1;
    }

    for (i = 0; i < FINE_PULSE_GEN_MAX_CHANNELS; i++)
    {
        dev->channels[i].index = i;
        dev->channels[i].delay_tap_size_ps = delay_tap_size_ps;
    }

    fine_pulse_gen_reset(dev);

    return 0;
}

void fine_pulse_gen_setup_channel(struct fine_pulse_gen_device *dev, int ch, int enable, int pps_offset_ps, int length_ps, int flags)
{
    dev->channels[ch].flags = flags;
    dev->channels[ch].pps_offset_ps = pps_offset_ps;
    dev->channels[ch].pulse_length_ps = length_ps;

    if (enable)
        dev->channels[ch].flags |= FINE_PULSE_GEN_ENABLED;
    else
        dev->channels[ch].flags &= ~FINE_PULSE_GEN_ENABLED;

    int polarity = flags & FINE_PULSE_GEN_NEGATIVE;

    uint32_t ocr_a = (polarity ? WB_FPGEN_OCR0A_POL : 0);
    uint32_t ocr_b = 0;

    fpgen_writel(dev, ocr_a, WB_FPGEN_OCR0A + 8 * ch);
    fpgen_writel(dev, ocr_b, WB_FPGEN_OCR0B + 8 * ch);
}

void fine_pulse_gen_set_external_fine_delay(struct fine_pulse_gen_device *dev, int ch, int tap_size, int (*set_external_delay)(struct fine_pulse_gen_channel *ch, int))
{
    dev->channels[ch].flags |= FINE_PULSE_GEN_USE_EXT_FINE_DELAY;
    dev->channels[ch].delay_tap_size_ps = tap_size;
    dev->channels[ch].set_external_delay = set_external_delay;
}

void fine_pulse_gen_force_pulse(struct fine_pulse_gen_device *dev, int channel)
{
    struct fine_pulse_gen_channel *ch = &dev->channels[channel];

    int polarity = ch->flags & FINE_PULSE_GEN_NEGATIVE;

    uint32_t ocr_a =
        (0x0 << WB_FPGEN_OCR0A_COARSE_SHIFT) | (0 << WB_FPGEN_OCR0A_FINE_SHIFT) | (polarity ? WB_FPGEN_OCR0A_POL : 0);

    // fixme pulse_length is in tics

    uint32_t ocr_b = (1 << WB_FPGEN_OCR0B_PPS_OFFS_SHIFT) | (ch->pulse_length_ps << WB_FPGEN_OCR0B_LENGTH_SHIFT);

    fpgen_writel(dev, ocr_a, WB_FPGEN_OCR0A + 8 * channel);
    fpgen_writel(dev, ocr_b, WB_FPGEN_OCR0B + 8 * channel);

    uint32_t trig_mask = (WB_FPGEN_CSR_FORCE0 << channel);

    fpgen_writel(dev, trig_mask, WB_FPGEN_CSR);

#ifdef FPGEN_EXTRA_VERBOSE
    dev_dbg("fpgen force sync ch %x ocr_a %08x ocr_b %08x mask %x pre %08x post %08x\n", channel, ocr_a, ocr_b, trig_mask, csr_pre, csr_post);
#endif
    ch->flags |= FINE_PULSE_GEN_CH_ARMED;
}

void fine_pulse_gen_trigger(struct fine_pulse_gen_device *dev, uint32_t mask, int force_now)
{
    int i;
    uint32_t trig_mask = 0;

    for (i = 0; i < FINE_PULSE_GEN_MAX_CHANNELS; i++)
    {
        struct fine_pulse_gen_channel *ch = &dev->channels[i];

        if ((ch->flags & FINE_PULSE_GEN_ENABLED) && (mask & (1 << i)))
        {
            int polarity = ch->flags & FINE_PULSE_GEN_NEGATIVE;
            int continuous = ch->flags & FINE_PULSE_GEN_CONTINUOUS;
            uint32_t coarse_range = dev->serdes_bit_length_ps * dev->serdes_ratio;

            uint32_t coarse_par = ch->pps_offset_ps / coarse_range;
            uint32_t coarse_ser = (ch->pps_offset_ps / dev->serdes_bit_length_ps) - coarse_par * dev->serdes_ratio;
            uint32_t fine = ch->pps_offset_ps - (coarse_par * coarse_range + coarse_ser * dev->serdes_bit_length_ps);

            fine /= ch->delay_tap_size_ps;

            uint32_t len_tics = ch->pulse_length_ps / coarse_range / 16;

#ifdef FPGEN_EXTRA_VERBOSE
            dev_dbg(
                "fpgen pulse: tap_size %d ps coarse_par %u coarse_ser %u fine_taps %u length_ps %d len_tics %d\n",
                ch->delay_tap_size_ps,
                coarse_par,
                coarse_ser,
                fine,
                ch->pulse_length_ps,
                len_tics);
#endif

            uint32_t ocr_b = (coarse_par << WB_FPGEN_OCR0B_PPS_OFFS_SHIFT) | (len_tics << WB_FPGEN_OCR0B_LENGTH_SHIFT);
            uint32_t ocr_a = (coarse_ser << WB_FPGEN_OCR0A_COARSE_SHIFT) | (fine << WB_FPGEN_OCR0A_FINE_SHIFT) | (continuous ? WB_FPGEN_OCR0A_CONT : 0) | (polarity ? WB_FPGEN_OCR0A_POL : 0);

            if (ch->flags & FINE_PULSE_GEN_USE_EXT_TRIGGER)
                ocr_a |= WB_FPGEN_OCR0A_TRIG_SEL;

            if (ch->flags & FINE_PULSE_GEN_USE_EXT_FINE_DELAY)
            {
                ch->set_external_delay(ch, fine);
            }

            ch->flags |= FINE_PULSE_GEN_CH_ARMED;

            trig_mask |= (1 << i);

            fpgen_writel(dev, ocr_a, WB_FPGEN_OCR0A + 8 * i);
            fpgen_writel(dev, ocr_b, WB_FPGEN_OCR0B + 8 * i);
        }
    }

    if (force_now)
        trig_mask <<= FPG_CSR_FORCE0_OFFSET; // fixme: use bitshifts from header file

    fpgen_writel(dev, trig_mask, WB_FPGEN_CSR); // arm trigger
}

int fine_pulse_gen_is_triggered(struct fine_pulse_gen_device *dev, uint32_t mask)
{
    uint32_t rv = fpgen_readl(dev, WB_FPGEN_CSR);
    int i;

    for(i = 0 ; i < FINE_PULSE_GEN_MAX_CHANNELS; i++ )
    {
        if( (mask & (1<<i)) == 0 )
            continue;

        struct fine_pulse_gen_channel* ch = &dev->channels[i];

        uint32_t ready_mask = 1 << (WB_FPGEN_CSR_READY_SHIFT + i);

        if( (ch->flags & FINE_PULSE_GEN_CH_ARMED) )
        {
            if( (rv & ready_mask) == 0 )
                return 0;
            else {
                ch->flags &= ~FINE_PULSE_GEN_CH_ARMED;
            }
        }
    }

    return 1;
}

int fine_pulse_gen_is_armed(struct fine_pulse_gen_device *dev, int ch)
{
    return (dev->channels[ch].flags & FINE_PULSE_GEN_CH_ARMED) ? 1 : 0;
}
