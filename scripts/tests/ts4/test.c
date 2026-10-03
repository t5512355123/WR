#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <limits.h>
#include "ppsi/ppsi.h"
#include "../../../vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-servo.c"

static char printed[8192];
static unsigned printed_len;
static int accept=1, e2e=1, phase_actions;
struct test_arch ts_arch={WRH_TM_BOUNDARY_CLOCK};
volatile uint32_t wrpc_spll_init_count=7;
static struct wrh_fixed_diag diagnostic={.phase_writes=41,.servo_inits=2};
void wrh_fixed_diag_get(struct wrh_fixed_diag *d) { *d=diagnostic; }
int pp_printf(const char *fmt, ...) {
    va_list ap; int n;
    va_start(ap,fmt); n=vsnprintf(printed+printed_len,sizeof(printed)-printed_len,fmt,ap); va_end(ap);
    assert(n>=0 && (unsigned)n<sizeof(printed)-printed_len); printed_len+=(unsigned)n; return n;
}
static void clear_print(void) { printed_len=0; printed[0]=0; }
int is_delayMechanismE2E(struct pp_instance *p) { return e2e; }
int is_delayMechanismP2P(struct pp_instance *p) { return !e2e; }
void pp_time_add(struct pp_time *a,const struct pp_time *b) { a->secs+=b->secs; a->scaled_nsecs+=b->scaled_nsecs; }
void pp_time_sub(struct pp_time *a,const struct pp_time *b) { a->secs-=b->secs; a->scaled_nsecs-=b->scaled_nsecs; }
int wrh_servo_init(struct pp_instance *p) { return 1; }
int wrh_servo_got_sync(struct pp_instance *p) {
    p->servo->t1=p->t1; p->servo->t2=p->t2; p->servo->got_sync=1; return 0;
}
int wrh_servo_got_presp(struct pp_instance *p) { return 0; }
int wrh_servo_got_resp(struct pp_instance *p) {
    if(!accept) return 0;
    p->servo->t3=p->t3; p->servo->t4=p->t4;
    p->servo->update_count++; p->servo->state=4;
    p->ext_data->servo.cur_setpoint_ps+=7;
    diagnostic.phase_writes++; phase_actions++;
    return 1;
}
int main(void) {
    struct pp_servo gs={.state=5}; struct test_wr_data wr={0};
    struct test_port port={.delayAsymmetry=-13};
    struct pp_instance p={.protocol_extension=PPSI_EXT_WR,.extState=PP_EXSTATE_ACTIVE,
        .servo=&gs,.ext_data=&wr,.portDS=&port,.recv_sync_sequence_id=0xabcd};
    unsigned i; uint32_t frozen[86]; struct pp_time before_t1;
    const unsigned char id[]={0xff,0xee,0xdd,0xcc,0xbb,0xaa,0x99,0x88};
    memcpy(p.received_ptp_header.sourcePortIdentity.clockIdentity.id,id,8);
    p.received_ptp_header.messageType=9; p.received_ptp_header.domainNumber=3;
    p.received_ptp_header.sourcePortIdentity.portNumber=4;
    p.received_ptp_header.sequenceId=0x1234;
    wr.servo_ext.delta_txm.scaled_nsecs=3;
    wr.servo_ext.delta_rxs.scaled_nsecs=4;
    wr.servo_ext.delta_txs.scaled_nsecs=5;
    wr.servo_ext.delta_rxm.scaled_nsecs=6;
    gs.delayMM.scaled_nsecs=111; gs.delayMS.scaled_nsecs=222;
    gs.meanDelay.scaled_nsecs=333; gs.offsetFromMaster.scaled_nsecs=-444;
    wr.servo.cur_setpoint_ps=-987;
    p.t1=(struct pp_time){.secs=0x123456789,.scaled_nsecs=12};
    p.t2=(struct pp_time){.secs=0x123456789,.scaled_nsecs=100};
    p.t3=(struct pp_time){.secs=0x123456789,.scaled_nsecs=200};
    p.t4=(struct pp_time){.secs=0x123456789,.scaled_nsecs=400};
    assert(wr_ts_diag_show_page(1)==-EAGAIN);
    assert(wr_ts_diag_show_page(16)==-EINVAL);
    before_t1=p.t1; wr_servo_got_sync(&p); assert(wr_servo_got_resp(&p)==1);
    assert(ts_total==1 && phase_actions==1);
    assert(ts_ring[0][0]==1 && ts_ring[0][1]==1 && ts_ring[0][2]==0x50004);
    assert(ts_ring[0][3]==(uint32_t)-987 && ts_ring[0][4]==(uint32_t)-980);
    assert(ts_ring[0][5]==0xabcd1234 && ts_ring[0][6]==0x09030004);
    assert(ts_ring[0][7]==0xffeeddcc && ts_ring[0][8]==0xbbaa9988);
    assert(ts_ring[0][10]==42 && ts_ring[0][11]==2 && ts_ring[0][13]==7);
    assert(ts_ring[0][16]==1 && ts_ring[0][17]==0x23456789 && ts_ring[0][19]==12);
    assert(ts_ring[0][35]==15 && ts_ring[0][39]==96 && ts_ring[0][43]==205 && ts_ring[0][47]==394);
    assert(ts_ring[0][79]==(uint32_t)-444 && ts_ring[0][84]==0xffffffff && ts_ring[0][85]==(uint32_t)-13);
    assert(wr.servo_ext.rawT1.secs==before_t1.secs && wr.servo_ext.rawT1.scaled_nsecs==before_t1.scaled_nsecs);
    accept=0; wr_servo_got_resp(&p); assert(ts_total==1);
    accept=1; ts_arch.timingMode=0; wr_servo_got_resp(&p); assert(ts_total==1);
    ts_arch.timingMode=WRH_TM_BOUNDARY_CLOCK; p.extState=0;
    wr_servo_got_resp(&p); assert(ts_total==1);
    p.extState=PP_EXSTATE_ACTIVE; e2e=0; wr_servo_got_resp(&p); assert(ts_total==1);
    e2e=1; p.protocol_extension=0; wr_servo_got_resp(&p); assert(ts_total==1);
    p.protocol_extension=PPSI_EXT_WR;
    for(i=0;i<30;i++) wr_servo_got_resp(&p);
    assert(ts_count==16 && ts_total==31);
    clear_print(); assert(wr_ts_diag_show_page(0)==0);
    assert(ts_snapshot_total==31 && ts_snapshot[0][0]==16 && ts_snapshot[15][0]==31);
    assert(strstr(printed,"TS4_PAGE v=1 snapshot=00000001 total=0000001f page=0 count=16 words=86"));
    assert(printed_len<2048 && strstr(printed,"TS4_END snapshot=00000001 page=0"));
    assert(printed_len+64<1024); /* echo, CRLF and prompt reserve; held FIFO */
    memcpy(frozen,ts_snapshot[1],sizeof(frozen));
    for(i=0;i<20;i++) wr_servo_got_resp(&p);
    clear_print(); assert(wr_ts_diag_show_page(1)==0);
    assert(ts_snapshot_total==31 && memcmp(frozen,ts_snapshot[1],sizeof(frozen))==0);
    ts_put64(frozen,INT64_MIN); assert(frozen[0]==0x80000000 && frozen[1]==0);
    ts_put64(frozen,INT64_MAX); assert(frozen[0]==0x7fffffff && frozen[1]==0xffffffff);
    puts("ACTUAL_TS4_RECORDER_C=PASS raw/cal fields action boundary filtering overwrite frozen pages signed64 no-control-input");
    return 0;
}
