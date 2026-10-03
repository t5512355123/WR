#include <assert.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <limits.h>
#include "../../../vendor/wrpc-sw/lib/phase-history.c"
static uint32_t now = 100;
volatile uint32_t wrpc_spll_init_count = 1;
static int coherent = 1;
uint32_t timer_get_tics(void) { return now; }
int spll_main_diag_copy(struct spll_main_diag_frame *p) {
    memset(p,0,sizeof(*p)); p->producer_epoch=4; p->update_id=999;
    p->sample_n=1000; p->branch_id=2; p->branch_error=-200;
    p->pi_output=32768; p->flags=1; p->init_generation=1;
    return coherent;
}
int spll_ptracker_diag_copy(unsigned ch,struct spll_ptracker_diag_frame *p) {
    assert(ch==0); memset(p,0,sizeof(*p)); p->epoch=6; p->generation=2;
    p->publications=3; p->phase_raw=-100; p->published_ms=90;
    p->ready_enabled=3; return coherent;
}
static char printed[4096]; static unsigned n;
int pp_printf(const char *fmt,...) {
    va_list ap; int k; va_start(ap,fmt);
    k=vsnprintf(printed+n,sizeof(printed)-n,fmt,ap); va_end(ap);
    assert(k>=0 && (unsigned)k<sizeof(printed)-n); n+=(unsigned)k; return k;
}
int main(void) {
    unsigned i; uint32_t frozen[36];
    assert(wr_phase_history_show_page(1)==-EAGAIN);
    assert(wr_phase_history_show_page(16)==-EINVAL);
    for(i=0;i<40;i++)
        wr_phase_history_record(i+1,0x40004,12,12,5,0,-100,0,10000);
    assert(count==32 && total==40 && ring[7][0]==40);
    assert(ring[7][10]==0xffffffff && ring[7][11]==(uint32_t)-100);
    assert(ring[7][20]==(uint32_t)-200 && ring[7][25]==1000);
    assert(wr_phase_history_show_page(0)==0);
    assert(snapshot[0][0]==9 && snapshot[31][0]==40);
    assert(n+64<1024 && strstr(printed,"PHIST_END snapshot=00000001 page=0"));
    memcpy(frozen,snapshot[2],sizeof(frozen));
    for(i=0;i<35;i++) wr_phase_history_record(41+i,4,12,12,5,0,INT64_MIN,0,INT64_MAX);
    n=0; assert(wr_phase_history_show_page(1)==0);
    assert(memcmp(frozen,snapshot[2],sizeof(frozen))==0 && snapshot_total==40);
    coherent=0; wr_phase_history_record(76,4,12,12,5,0,0,0,0);
    assert(ring[(head+31)%32][16]==0 && ring[(head+31)%32][26]==0);
    assert(ring[(head+31)%32][17]==0 && ring[(head+31)%32][30]==0);
    puts("ACTUAL_PHASE_HISTORY_C=PASS signed64 freeze wrap fifo coherent-invalid no-control-input");
    return 0;
}
