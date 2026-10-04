/* Execute the actual diagnostic production C, with no hardware attached. */
#define main historical_reference_main
#include "time_valid_baseline_test.c"
#undef main

#if WRH_PHASE_CORRECTION_ENABLED != 0
#error "This test must execute the actual default-disabled diagnostic"
#endif

int main(void) {
    const int offsets[] = {-7999,-121,-120,-61,-60,-59,-23,0,23,59,60,61,120,121,7999};
    const int inband[] = {-59,0,59}, outband[] = {-61,-60,60,61};
    unsigned i, cases = 0;

    for (i=0; i<sizeof(offsets)/sizeof(*offsets); i++) {
        int offset = offsets[i];
        fixture(WRH_SYNC_PHASE, offset); ws.cur_setpoint_ps=2345;
        __wrh_servo_update(&instance);
        assert(ws.cur_setpoint_ps==2345 && phase_calls==0 && counter_calls==0);
        assert(gs.state==WRH_WAIT_OFFSET_STABLE && !(gs.flags & PP_SERVO_FLAG_WAIT_HW));
        assert(gs.update_count==1 && ws.offsetMS_ps==offset && !ws.tracking_enabled);
        cases++;

        fixture(WRH_TRACK_PHASE, offset); ws.cur_setpoint_ps=2345;
        __wrh_servo_update(&instance);
        assert(ws.cur_setpoint_ps==2345 && phase_calls==0 && counter_calls==0);
        assert(gs.state==(abs(offset)>120 ? WRH_SYNC_PHASE : WRH_TRACK_PHASE));
        assert(gs.update_count==1 && !ws.tracking_enabled && output==1 && enables==0);
        cases++;
    }
    for (i=0; i<sizeof(inband)/sizeof(*inband); i++) {
        fixture(WRH_WAIT_OFFSET_STABLE, inband[i]); ws.cur_setpoint_ps=2345;
        __wrh_servo_update(&instance);
        assert(gs.state==WRH_TRACK_PHASE && output==1 && enables==1);
        assert(ws.cur_setpoint_ps==2345 && phase_calls==0);
        cases++;
    }
    for (i=0; i<sizeof(outband)/sizeof(*outband); i++) {
        fixture(WRH_WAIT_OFFSET_STABLE, outband[i]); ws.cur_setpoint_ps=2345;
        __wrh_servo_update(&instance);
        assert(gs.state==WRH_WAIT_OFFSET_STABLE && output==0 && enables==0);
        assert(ws.cur_setpoint_ps==2345 && phase_calls==0);
        cases++;
    }
    fixture(WRH_WAIT_OFFSET_STABLE, 200); ws.cur_setpoint_ps=2345; ws.missed_iters=9;
    __wrh_servo_update(&instance);
    assert(gs.state==WRH_SYNC_PHASE && ws.missed_iters==0 && phase_calls==0);
    assert(ws.cur_setpoint_ps==2345); cases++;

    /* Init/reinit/reset and IPC tracking cannot reactivate phase writes. */
    fixture(WRH_SYNC_PHASE, 0); ws.cur_setpoint_ps=16400;
    wrh_servo_init(&instance);
    assert(ws.cur_setpoint_ps==16400 && phase_calls==0 && !ws.tracking_enabled);
    wrh_servo_reset(&instance); wrh_servo_enable_tracking(1); wrh_servo_init(&instance);
    assert(ws.cur_setpoint_ps==16400 && phase_calls==0 && !ws.tracking_enabled);
    cases+=2;
    for (i=0; i<2; i++) {
        fixture(WRH_SYNC_PHASE, 600); ws.cur_setpoint_ps=2345; wrh_servo_enable_tracking(i);
        __wrh_servo_update(&instance);
        assert(ws.cur_setpoint_ps==2345 && phase_calls==0 && !ws.tracking_enabled);
        fixture(WRH_TRACK_PHASE, 60); ws.cur_setpoint_ps=2345; wrh_servo_enable_tracking(i);
        __wrh_servo_update(&instance);
        assert(ws.cur_setpoint_ps==2345 && phase_calls==0 && !ws.tracking_enabled);
        cases+=2;
    }
    /* Coarse sync remains operational: it is NOT a pure oscillator open loop. */
    fixture(WRH_TRACK_PHASE, 0); ws.cur_setpoint_ps=2345; gs.offsetFromMaster.secs=1;
    __wrh_servo_update(&instance);
    assert(counter_calls==1 && phase_calls==0 && ws.cur_setpoint_ps==2345);
    assert(gs.state==WRH_SYNC_PHASE); cases++;
    fixture(WRH_TRACK_PHASE, 16000); ws.cur_setpoint_ps=2345;
    __wrh_servo_update(&instance);
    assert(counter_calls==1 && phase_calls==0 && ws.cur_setpoint_ps==2345);
    assert(gs.state==WRH_SYNC_PHASE); cases++;

    fixture(WRH_SYNC_PHASE, 0); ws.cur_setpoint_ps=2345; pll=1;
    __wrh_servo_update(&instance);
    assert(ws.doRestart && phase_calls==0 && ws.cur_setpoint_ps==2345); cases++;
    fixture(WRH_SYNC_PHASE, 0); ws.cur_setpoint_ps=2345; busy=1;
    __wrh_servo_update(&instance);
    assert(gs.state==WRH_SYNC_PHASE && phase_calls==0 && ws.cur_setpoint_ps==2345); cases++;

    /* Retain a changing measurement stream rather than hard-coding CKO. */
    fixture(WRH_TRACK_PHASE, 0); ws.cur_setpoint_ps=2345;
    for (i=0; i<100; i++) {
        gs.offsetFromMaster.ps = ((int)i%119)-59;
        gs.delayMS.ps = 170000+i;
        __wrh_servo_update(&instance);
        assert(gs.update_count==i+1 && ws.offsetMS_ps==gs.offsetFromMaster.ps);
        assert(ws.delayMS_ps==gs.delayMS.ps && ws.cur_setpoint_ps==2345);
        assert(phase_calls==0 && !ws.tracking_enabled && gs.state==WRH_TRACK_PHASE);
    }
    cases+=100;
    printf("ACTUAL_NO_WR_PHASE_CORRECTION=PASS cases=%u phase_writes=0 measurements_live=1 unchanged_60_120=1 coarse_sync_active=1\n", cases);
    return 0;
}
