#include "board.h"
#include "pp-printf.h"
#include "dev/clock_monitor.h"
#include "hw/rawmem.h"
#include "util.h"

#include "hw/clock_monitor_regs.h"

int wb_cm_init(struct wb_clock_monitor_device *dev, uint32_t base_addr, unsigned n_channels )
{
    dev->base =base_addr;
    dev->freq_valid_mask = 0;
    dev->n_channels = n_channels;
    dev->ref_freq = 125000000;
    return 0;
}

void wb_cm_set_ref_frequency( struct wb_clock_monitor_device *dev, unsigned ref_freq )
{
    dev->ref_freq = ref_freq;
    dev->freq_valid_mask = 0;
}


int wb_cm_restart( struct wb_clock_monitor_device *dev )
{
    uint32_t cr = readl( (void *) (dev->base + CM_REG_CR) );
    cr |= CM_CR_CNT_RST;
    dev->freq_valid_mask = 0;

    writel( cr, (void *) (dev->base + CM_REG_CR) );
    return 0;
}

int wb_cm_configure(struct wb_clock_monitor_device *dev, unsigned ref_sel, unsigned prescaler, unsigned gate_freq)
{
    dev->freq_valid_mask = 0;
    dev->ref_sel = ref_sel;
    dev->prescaler = prescaler;
    dev->gate_freq = gate_freq;

    writel( (dev->ref_sel << CM_CR_REFSEL_SHIFT)
	    | (dev->prescaler << CM_CR_PRESC_SHIFT),
	    (void *) (dev->base + CM_REG_CR) );
    writel( dev->gate_freq, (void *) (dev->base + CM_REG_REFDR) );

    return wb_cm_restart(dev);
}

int wb_cm_read(struct wb_clock_monitor_device *dev)
{
    int i;
    uint32_t rv;

    for(i = 0; i < dev->n_channels; i++)
    {
        writel( i, (void *) (dev->base + CM_REG_CNT_SEL) );
        rv = readl ( (void *) (dev->base + CM_REG_CNT_VAL) );

        if( rv & CM_CNT_VAL_VALID )
        {
	    uint64_t freq;

	    freq = (uint64_t)(rv & 0x7fffffff) * dev->ref_freq;
	    __div64_32(&freq, dev->gate_freq);
            dev->freqs[i] = freq;
            dev->freq_valid_mask |= (1<<i);
        }
        writel( CM_CNT_VAL_VALID, (void *) (dev->base + CM_REG_CNT_VAL) );
    }

    return dev->freq_valid_mask;
}

int wb_cm_show(struct wb_clock_monitor_device *dev)
{
    int i;

    for( i = 0; i < dev->n_channels; i++ )
    {
        if( dev->freq_valid_mask & (1<<i))
        {
            pp_printf("Chan %d: %u Hz\n", i, dev->freqs[i]);
        }
    }
    return 0;
}
