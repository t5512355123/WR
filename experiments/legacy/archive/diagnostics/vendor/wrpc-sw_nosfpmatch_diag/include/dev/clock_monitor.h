#ifndef __CLOCK_MONITOR_H
#define __CLOCK_MONITOR_H

#include <stdint.h>

#define CM_MAX_CHANNELS 16

struct wb_clock_monitor_device
{
    uint32_t base;
    unsigned prescaler;
    unsigned gate_freq;
    unsigned ref_sel;
    unsigned n_channels;
    unsigned ref_freq;
    unsigned freqs[CM_MAX_CHANNELS];
    uint32_t freq_valid_mask;
};

int wb_cm_init( struct wb_clock_monitor_device *dev, uint32_t base_addr, unsigned n_channels );
int wb_cm_restart( struct wb_clock_monitor_device *dev );
int wb_cm_configure(  struct wb_clock_monitor_device *dev, unsigned ref_sel, unsigned prescaler, unsigned gate_freq );
int wb_cm_read(struct wb_clock_monitor_device *dev);
int wb_cm_show(struct wb_clock_monitor_device *dev);
void wb_cm_set_ref_frequency( struct wb_clock_monitor_device *dev, unsigned ref_freq );

#endif
