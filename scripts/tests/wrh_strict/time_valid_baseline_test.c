/* Execute the intact historical controller, including its actual validity
 * semantics. This is not the superseded full64 strict-offset test. */
#include <assert.h>
#include <stdio.h>
#define __COMMON_FUN_H
#include "ppsi/ppsi.h"
#include "../../../vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c"

static int output, enables, busy, pll, delays_ok, phase_calls, counter_calls;
static struct pp_servo gs;
struct test_arch_data test_arch;
static wrh_servo_t ws;
static struct pp_instance instance = { .servo=&gs, .ext_data=&ws };
static int enable_output(void *p, int enable) { output=enable; enables++; return 0; }
static int get_time(struct pp_instance *p, struct pp_time *t) { return 0; }
static int set_time(struct pp_instance *p, struct pp_time *t) { return 0; }
static int lock_poll(struct pp_instance *p) { return pll; }
static int is_busy(void) { return busy; }
static int counters(int64_t sec, int32_t ns) { counter_calls++; return 0; }
static int phase(int32_t ps) { phase_calls++; return 0; }
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
static void fixture(int state,int offset) {
    memset(&gs,0,sizeof(gs)); memset(&ws,0,sizeof(ws));
    instance.extState=PP_EXSTATE_ACTIVE; gs.state=state;
    gs.offsetFromMaster.ps=offset; ws.readyForSync=1; ws.clock_period_ps=8000;
    output=(state==WRH_TRACK_PHASE); enables=0; busy=0; pll=0; delays_ok=1;
    phase_calls=counter_calls=0; wrh_servo_enable_tracking(1);
}
int main(void) {
    const int entry_yes[]={-59,0,59}, entry_no[]={-61,-60,60,61};
    const int track_yes[]={-120,-60,0,60,120}, fallback[]={-121,121};
    unsigned i;
    for(i=0;i<sizeof(entry_yes)/sizeof(*entry_yes);i++) {
        fixture(WRH_WAIT_OFFSET_STABLE,entry_yes[i]); __wrh_servo_update(&instance);
        assert(output==1 && enables==1 && gs.state==WRH_TRACK_PHASE);
    }
    for(i=0;i<sizeof(entry_no)/sizeof(*entry_no);i++) {
        fixture(WRH_WAIT_OFFSET_STABLE,entry_no[i]); __wrh_servo_update(&instance);
        assert(output==0 && enables==0 && gs.state==WRH_WAIT_OFFSET_STABLE);
    }
    for(i=0;i<sizeof(track_yes)/sizeof(*track_yes);i++) {
        fixture(WRH_TRACK_PHASE,track_yes[i]); __wrh_servo_update(&instance);
        assert(output==1 && gs.state==WRH_TRACK_PHASE && phase_calls==1);
    }
    for(i=0;i<sizeof(fallback)/sizeof(*fallback);i++) {
        fixture(WRH_TRACK_PHASE,fallback[i]); __wrh_servo_update(&instance);
        assert(output==1 && enables==0 && gs.state==WRH_SYNC_PHASE && phase_calls==0);
    }
    fixture(WRH_SYNC_PHASE,200); ws.cur_setpoint_ps=1000;
    __wrh_servo_update(&instance);
    assert(ws.cur_setpoint_ps==1100 && output==0 && enables==0);
    fixture(WRH_TRACK_PHASE,60); ws.cur_setpoint_ps=1000;
    __wrh_servo_update(&instance); assert(ws.cur_setpoint_ps==1005);
    fixture(WRH_TRACK_PHASE,0); pll=1; __wrh_servo_update(&instance);
    assert(ws.doRestart && phase_calls==0);
    fixture(WRH_WAIT_OFFSET_STABLE,0); pll=1; __wrh_servo_update(&instance);
    assert(output==0 && enables==0 && ws.doRestart);
    fixture(WRH_WAIT_OFFSET_STABLE,0); delays_ok=0; __wrh_servo_update(&instance);
    assert(output==0 && enables==0);
    fixture(WRH_WAIT_OFFSET_STABLE,0); ws.readyForSync=0; __wrh_servo_update(&instance);
    assert(output==0 && enables==0);
    fixture(WRH_WAIT_OFFSET_STABLE,0); busy=1; __wrh_servo_update(&instance);
    assert(output==0 && enables==0);
    fixture(WRH_UNINITIALIZED,0); __wrh_servo_update(&instance);
    assert(output==0 && enables==0 && phase_calls==0);
    puts("ACTUAL_TIME_VALID_BASELINE_C_TEST=PASS cases=22 no_forced_entry=1 acquire=2 track=12 historical_validity=1");
    return 0;
}
