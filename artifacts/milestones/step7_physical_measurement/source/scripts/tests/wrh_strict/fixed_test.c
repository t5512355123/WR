/* Actual production C with fixed-setpoint intervention, hardware only stubbed. */
#define main baseline_test_main
#include "servo_test.c"
#undef main
static void boot_fixture(int state, int64_t offset)
{
    fixture(state, offset);
    memset(&fixed_diag, 0, sizeof(fixed_diag));
    fixed_diag.enabled = 1;
}
static void acquire(void)
{
    boot_fixture(WRH_WAIT_OFFSET_STABLE, 59);
    ws.cur_setpoint_ps = 17001;
    __wrh_servo_update(&instance);
    assert(fixed_diag.latched && fixed_diag.entry_update == 1);
    assert(output == 1 && gs.state == WRH_TRACK_PHASE);
    assert(ws.cur_setpoint_ps == fixed_diag.frozen_setpoint);
}
int main(void)
{
    unsigned i;
    const int64_t values[] = {-121,121,8000,-8000,INT32_MAX,INT32_MIN,INT64_MAX,INT64_MIN};
    acquire();
    for (i=0; i<100; i++) {
        gs.offsetFromMaster.ps = (int)(i%241)-120;
        wrh_servo_enable_tracking(i&1);
        __wrh_servo_update(&instance);
        assert(output == 1 && phase_calls == 0 && ws.cur_setpoint_ps == 17001);
    }
    for (i=0; i<sizeof(values)/sizeof(*values); i++) {
        acquire(); busy=1; gs.offsetFromMaster.ps=values[i];
        __wrh_servo_update(&instance);
        assert(output==0 && fixed_diag.revoked && phase_calls==0);
        assert(gs.state==WRH_TRACK_PHASE && ws.cur_setpoint_ps==17001);
    }
    acquire(); gs.offsetFromMaster.ps=121; wrh_servo_enable_tracking(0);
    __wrh_servo_update(&instance);
    gs.offsetFromMaster.ps=0; wrh_servo_enable_tracking(1);
    __wrh_servo_update(&instance);
    assert(output==0 && phase_calls==0 && fixed_diag.revoked);
    acquire(); wrh_servo_init(&instance);
    assert(output==0 && fixed_diag.latched && fixed_diag.servo_inits==1);
    assert(ws.cur_setpoint_ps==17001 && phase_calls==0);
    ws.readyForSync=1; gs.state=WRH_SYNC_PHASE; gs.offsetFromMaster.ps=200;
    __wrh_servo_update(&instance);
    assert(output==0 && ws.cur_setpoint_ps==17001 && phase_calls==0);
    gs.state=WRH_WAIT_OFFSET_STABLE; gs.offsetFromMaster.ps=0;
    __wrh_servo_update(&instance); assert(output==0 && fixed_diag.entry_update==1);
    acquire(); wrh_servo_reset(&instance);
    assert(output==0 && fixed_diag.latched && ws.cur_setpoint_ps==17001);
    acquire(); pll=1; __wrh_servo_update(&instance);
    assert(output==0 && ws.doRestart && fixed_diag.latched);
    acquire(); delays_ok=0; __wrh_servo_update(&instance); assert(output==0);
    acquire(); ws.readyForSync=0; __wrh_servo_update(&instance); assert(output==0);
    acquire(); gs.offsetFromMaster.secs=1; gs.offsetFromMaster.ps=0;
    __wrh_servo_update(&instance); assert(output==0 && counter_calls==1 && phase_calls==0);
    boot_fixture(WRH_WAIT_OFFSET_STABLE,0); test_arch.timingMode=WRH_TM_FREE_MASTER;
    __wrh_servo_update(&instance); assert(!fixed_diag.latched);
    wrh_servo_init(&instance); assert(output==1 && phase_calls==1);
    boot_fixture(WRH_SYNC_PHASE,200); ws.cur_setpoint_ps=1000;
    __wrh_servo_update(&instance); assert(ws.cur_setpoint_ps==1100 && phase_calls==1);
    puts("ACTUAL_FIXED_SETP_C_TEST=PASS in_band_updates=100 full64_revocations=8 all_phase_paths_guarded=1");
    return 0;
}
