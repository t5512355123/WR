/*
 * This work is part of the White Rabbit project
 *
 * Released according to the GNU GPL, version 2 or any later version.
 */

#ifndef __WRC_DEBUG_H
#define __WRC_DEBUG_H

#include "pp-printf.h"

#define WRC_DEFINE_TRACE_MSG(subsys_name, trace_func_name) \
    static inline void trace_func_name(const char *fmt, ...)             \
    {                                                                    \
            va_list vargs;                                               \
            va_start(vargs, fmt);                                        \
            pp_printf("[" subsys_name "] ");                            \
            pp_vprintf(fmt, vargs);                                      \
            va_end(vargs);                                               \
    }

/* If the trace is not enabled, define an empty macro so that any side
   effect is discarded. Calls like format_mac are then eliminated.
   Previously, the test was done within the inline function so the call was
   kept albeit useless. */
#if (CONFIG_TRACE_ALL || CONFIG_TRACE_MAIN) && !CONFIG_BOOTLOADER
WRC_DEFINE_TRACE_MSG("main", main_dbg)
#else
#define main_dbg(...)
#endif

#if (CONFIG_TRACE_ALL || CONFIG_TRACE_STORAGE) && !CONFIG_BOOTLOADER
WRC_DEFINE_TRACE_MSG("storage", storage_dbg)
#else
#define storage_dbg(...)
#endif

#if (CONFIG_TRACE_ALL || CONFIG_TRACE_DEVICES) && !CONFIG_BOOTLOADER
WRC_DEFINE_TRACE_MSG("dev", dev_dbg)
#else
#define dev_dbg(...)
#endif

#if (CONFIG_TRACE_ALL || CONFIG_TRACE_BOARD) && !CONFIG_BOOTLOADER
WRC_DEFINE_TRACE_MSG("board", board_dbg)
#else
#define board_dbg(...)
#endif

#if (CONFIG_TRACE_ALL || CONFIG_TRACE_MAC) && !CONFIG_BOOTLOADER
WRC_DEFINE_TRACE_MSG("mac", mac_dbg)
#else
#define mac_dbg(...)
#endif


#if (CONFIG_TRACE_ALL || CONFIG_TRACE_PHY) && !CONFIG_BOOTLOADER
WRC_DEFINE_TRACE_MSG("phy", phy_dbg)
#else
#define phy_dbg(...)
#endif

#endif
