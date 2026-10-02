#ifndef WRH_FIXED_DIAG_H
#define WRH_FIXED_DIAG_H
#include <stdint.h>
/* Current experiment only. Override to zero for baseline regression tests. */
#ifndef WRH_FIXED_SETP_DIAGNOSTIC
#define WRH_FIXED_SETP_DIAGNOSTIC 1
#endif
struct wrh_fixed_diag {
    uint32_t enabled, latched, entry_update, phase_writes, servo_inits, revoked;
    int32_t frozen_setpoint;
};
void wrh_fixed_diag_get(struct wrh_fixed_diag *result);
#endif
