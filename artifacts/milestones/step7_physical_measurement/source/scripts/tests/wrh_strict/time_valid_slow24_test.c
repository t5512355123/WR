/* Actual production servo, not an alternate simulation controller. */
#define EXPECTED_ACQUIRE_DIV 24
#define EXPECTED_TRACK_DIV 24
#define main baseline_main
#include "time_valid_baseline_test.c"
#undef main

int main(void) {
    const int offsets[]={-7999,-120,-59,-24,-23,0,23,24,59,120,7999};
    unsigned i, extra=0;
    baseline_main();
    for(i=0;i<sizeof(offsets)/sizeof(*offsets);i++) {
        int offset=offsets[i];
        fixture(WRH_SYNC_PHASE,offset); ws.cur_setpoint_ps=1000;
        __wrh_servo_update(&instance);
        assert(ws.cur_setpoint_ps==1000+offset/24);
        assert(phase_calls==1 && output==0 && gs.state==WRH_WAIT_OFFSET_STABLE);
        extra++;
        if(abs(offset)<=120) {
            fixture(WRH_TRACK_PHASE,offset); ws.cur_setpoint_ps=1000;
            __wrh_servo_update(&instance);
            assert(ws.cur_setpoint_ps==1000+offset/24);
            assert(phase_calls==1 && output==1 && gs.state==WRH_TRACK_PHASE);
            extra++;
        }
    }
    printf("ACTUAL_SERVO_SLOW24_NATIVE=PASS cases=%u signed_truncation=1 unchanged_60_120=1\n",22+extra);
    return 0;
}
