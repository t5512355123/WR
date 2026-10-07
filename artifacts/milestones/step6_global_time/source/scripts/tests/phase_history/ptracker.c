#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#define __SOFTPLL_NG_H
#define CONFIG_WR_NODE 1
#define MAIN_CHANNEL 1
#define MAX_PTRACKERS 1
#define HPLL_N 14
#define SPLL_DBG_SIGNAL_ERR 0
#define SPLL_DBG_SRC_AUX(x) (x)
#include "../../../vendor/wrpc-sw/softpll/spll_ptracker.h"
static unsigned tagger_calls;
void spll_enable_tagger(int a,int b) { (void)a; assert(b==1); tagger_calls++; }
void spll_debug(int a,int b,int c,int d) { (void)a;(void)b;(void)c;(void)d; }
uint32_t timer_get_tics(void) { return 1234; }
#include "../../../vendor/wrpc-sw/softpll/spll_ptracker.c"
int main(void) {
    struct spll_ptracker_state s={0}; struct spll_ptracker_diag_frame d;
    unsigned i;
    ptracker_init(&s,0,512); assert(s.n_avg==512 && !s.ready);
    assert(spll_ptracker_diag_copy(0,&d) && d.generation==1 && !d.publications);
    ptracker_start(&s); assert(tagger_calls==2 && s.enabled && !s.ready);
    assert(spll_ptracker_diag_copy(0,&d) && d.generation==2 && d.ready_enabled==2);
    for(i=0;i<512;i++) {
        ptrackers_update(&s,1000+(int)i,1);
        ptrackers_update(&s,1123+(int)i,0);
    }
    assert(s.ready && s.phase_val==123 && !s.avg_count && !s.acc);
    assert(spll_ptracker_diag_copy(0,&d) && d.publications==1 && d.phase_raw==123);
    assert(d.published_ms==1234 && d.ready_enabled==3 && d.reference_tag==1511 && d.input_tag==1634);
    ptracker_diag[0].epoch|=1; assert(!spll_ptracker_diag_copy(0,&d));
    ptracker_diag[0].epoch++;
    ptracker_start(&s); assert(spll_ptracker_diag_copy(0,&d));
    assert(d.generation==3 && d.publications==0 && d.published_ms==0 && d.phase_raw==0);
    assert(!spll_ptracker_diag_copy(1,&d) && !spll_ptracker_diag_copy(0,0));
    s.enabled=0; ptrackers_update(&s,100,0); assert(!s.avg_count);
    puts("ACTUAL_PTRACKER_PASSIVE_C=PASS actual512average unchanged-starts bounded-seqlock private-ABI");
    return 0;
}
