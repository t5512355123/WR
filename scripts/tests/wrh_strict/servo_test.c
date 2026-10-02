/* Executes the actual current wrh-servo.c; only external hardware is stubbed. */
#include <assert.h>
#include <stdio.h>
#include <limits.h>
#define __COMMON_FUN_H
#include "ppsi/ppsi.h"
#include "../../../vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"

static int output, busy, pll, delays_ok, phase_calls, counter_calls;
static struct pp_servo gs;
struct test_arch_data test_arch;
static wrh_servo_t ws;
static struct pp_instance instance = { .servo=&gs, .ext_data=&ws };
static int enable_output(void *unused,int enable) { output=enable; return 0; }
static int get_time(struct pp_instance *p,struct pp_time *t) { return 0; }
static int set_time(struct pp_instance *p,struct pp_time *t) { return 0; }
static int lock_poll(struct pp_instance *p) { return pll; }
static int is_busy(void) { return busy; }
static int counters(int64_t sec,int32_t ns) { counter_calls++; return 0; }
static int phase(int32_t ps) {
    if(test_arch.timingMode==WRH_TM_BOUNDARY_CLOCK && gs.state!=WRH_TRACK_PHASE)
        assert(output==0);
    phase_calls++; return 0;
}
static int32_t period(void) { return 8000; }
struct test_time_ops test_tops = {get_time,set_time,enable_output};
struct test_time_ops unix_time_ops = {get_time,set_time,enable_output};
struct test_wrh_ops test_ops = {lock_poll,is_busy,counters,phase,period};
void pp_servo_init(struct pp_instance *p) {}
int pp_servo_calculate_delays(struct pp_instance *p) { return delays_ok; }
int64_t pp_time_to_picos(const struct pp_time *t) { return t->ps; }
void pp_time_hardwarize(const struct pp_time *t,int32_t cp,int32_t *ticks,int32_t *ps) {
    *ticks=(int32_t)(t->ps/cp); *ps=(int32_t)(t->ps%cp);
}
int is_delayMechanismP2P(struct pp_instance *p) { return 0; }
int is_timestamp_incorrect_thres(struct pp_instance *p,int *ec,int mask) { return 0; }
void apply_faulty_stamp(struct pp_instance *p,int n) {}
const char *time_to_string(const struct pp_time *t) { return "test"; }
static void fixture(int state,int64_t offset) {
    memset(&gs,0,sizeof(gs)); memset(&ws,0,sizeof(ws));
    instance.extState=PP_EXSTATE_ACTIVE; gs.state=state;
    test_arch.timingMode=WRH_TM_BOUNDARY_CLOCK;
    gs.servo_locked=(state==WRH_TRACK_PHASE);
    gs.offsetFromMaster.ps=offset; ws.readyForSync=1; ws.clock_period_ps=8000;
    output=(state==WRH_TRACK_PHASE); busy=0; pll=0; delays_ok=1;
    phase_calls=counter_calls=0; wrh_servo_enable_tracking(1);
}
int main(void) {
    const int64_t entry_ok[]={-59,0,59};
    const int64_t entry_no[]={-61,-60,60,61};
    const int64_t retain[]={-120,-60,0,60,120};
    const int64_t revoke[]={-121,121,8000,-8000,INT32_MAX,INT32_MIN,INT64_MAX,INT64_MIN};
    unsigned i;
    for(i=0;i<sizeof(entry_ok)/sizeof(*entry_ok);i++) {
        fixture(WRH_WAIT_OFFSET_STABLE,entry_ok[i]); ws.missed_iters=9;
        __wrh_servo_update(&instance);
        assert(output==1 && gs.state==WRH_TRACK_PHASE && ws.missed_iters==0);
    }
    for(i=0;i<sizeof(entry_no)/sizeof(*entry_no);i++) {
        fixture(WRH_WAIT_OFFSET_STABLE,entry_no[i]); __wrh_servo_update(&instance);
        assert(output==0 && gs.state==WRH_WAIT_OFFSET_STABLE);
    }
    for(i=0;i<sizeof(retain)/sizeof(*retain);i++) {
        fixture(WRH_TRACK_PHASE,retain[i]); __wrh_servo_update(&instance);
        assert(output==1 && gs.state==WRH_TRACK_PHASE);
    }
    for(i=0;i<sizeof(revoke)/sizeof(*revoke);i++) {
        fixture(WRH_TRACK_PHASE,revoke[i]); busy=1;
        __wrh_servo_update(&instance);
        assert(output==0 && gs.state==WRH_SYNC_PHASE && gs.servo_locked==0);
        assert(phase_calls==0 && counter_calls==0);
    }
    fixture(WRH_TRACK_PHASE,121); wrh_servo_enable_tracking(0);
    __wrh_servo_update(&instance); assert(output==0);
    fixture(WRH_TRACK_PHASE,0); busy=1; __wrh_servo_update(&instance); assert(output==1);
    fixture(WRH_TRACK_PHASE,0); gs.offsetFromMaster.secs=1;
    __wrh_servo_update(&instance); assert(output==0 && counter_calls==1);
    fixture(WRH_TRACK_PHASE,0); pll=1;
    __wrh_servo_update(&instance); assert(output==0 && ws.doRestart);
    fixture(WRH_TRACK_PHASE,0); delays_ok=0;
    __wrh_servo_update(&instance); assert(output==0 && gs.servo_locked==0);
    fixture(WRH_TRACK_PHASE,0); ws.readyForSync=0;
    __wrh_servo_update(&instance); assert(output==0);
    fixture(WRH_TRACK_PHASE,0); wrh_servo_init(&instance);
    assert(output==0 && gs.state==WRH_SYNC_TAI);
    fixture(WRH_TRACK_PHASE,0); wrh_servo_reset(&instance);
    assert(output==0 && gs.state==WRH_UNINITIALIZED);
    fixture(WRH_UNINITIALIZED,0); output=1;
    __wrh_servo_update(&instance); assert(output==0);
    fixture(WRH_SYNC_PHASE,200); ws.cur_setpoint_ps=1000;
    __wrh_servo_update(&instance); assert(ws.cur_setpoint_ps==1100 && output==0);
    fixture(WRH_TRACK_PHASE,60); ws.cur_setpoint_ps=1000;
    __wrh_servo_update(&instance); assert(ws.cur_setpoint_ps==1005 && output==1);
    fixture(WRH_TRACK_PHASE,0); test_arch.timingMode=WRH_TM_FREE_MASTER;
    wrh_servo_reset(&instance); assert(output==1);
    fixture(WRH_TRACK_PHASE,0); test_arch.timingMode=WRH_TM_FREE_MASTER;
    wrh_servo_init(&instance); assert(output==1);
    fixture(WRH_UNINITIALIZED,0); output=1; test_arch.timingMode=WRH_TM_FREE_MASTER;
    __wrh_servo_update(&instance); assert(output==1);
    fixture(WRH_TRACK_PHASE,0); test_arch.timingMode=WRH_TM_GRAND_MASTER;
    wrh_servo_reset(&instance); assert(output==1);
    puts("ACTUAL_WRH_SERVO_C_TEST=PASS cases=35 acquisition_divisor=2 tracking_divisor=12 master_gm_preserved=1");
    return 0;
}
