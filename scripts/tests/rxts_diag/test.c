#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <string.h>
#include "../../../vendor/wrpc-sw/lib/rxts-diag.c"
static char printed[8192];
static unsigned used;
int pp_printf(const char *format, ...)
{
    int n; va_list ap;
    va_start(ap, format);
    n = vsnprintf(printed + used, sizeof(printed) - used, format, ap);
    va_end(ap);
    assert(n >= 0 && (unsigned)n < sizeof(printed) - used);
    used += n;
    return n;
}
static void show(unsigned page)
{
    used = 0; printed[0] = 0;
    assert(rxts_diag_show_page(page) == 0);
    assert(used < 1024);
    assert(strstr(printed, "RXTS_END"));
}
int main(void)
{
    uint8_t p[64] = {0};
    struct wr_timestamp ts = { .sec=42, .nsec=16, .phase=100,
        .raw_phase=100, .raw_nsec=16, .raw_ahead=1, .correct=1 };
    struct wr_timestamp original = ts;
    unsigned i;
    assert(rxts_diag_show_page(1) == -EAGAIN);
    assert(rxts_diag_show_page(8) == -EINVAL);
    show(0); assert(snapshot_count == 0);
    p[1]=2; p[3]=44; p[31]=7; p[28]=0x12; p[29]=0x34;
    p[20]=1; p[27]=2; p[34]=1; p[39]=3; p[43]=4;
    rxts_diag_record(p, 33, &ts, 41, 7050, 8000);
    p[1]=1; rxts_diag_record(p, 64, &ts, 41, 7050, 8000);
    p[1]=2; p[0]=4; rxts_diag_record(p, 64, &ts, 41, 7050, 8000);
    p[0]=9; rxts_diag_record(p, 64, &ts, 41, 7050, 8000);
    p[0]=0; p[3]=65; rxts_diag_record(p, 64, &ts, 41, 7050, 8000);
    assert(total == 0);
    p[3]=44;
    rxts_diag_record(p, 64, &ts, (int64_t)0x123456789LL, 7050, 8000);
    assert(memcmp(&ts, &original, sizeof(ts)) == 0);
    assert(ring[0][0] == 1 && ring[0][1] == 7);
    assert(ring[0][2] == 0x01000000 && ring[0][3] == 2);
    assert(ring[0][4] == 0x71234);
    assert(ring[0][5] == 1 && ring[0][6] == 0x23456789);
    assert(ring[0][9] == 7050 && ring[0][11] == 42);
    assert(ring[0][14] == 0x100 && ring[0][15] == 3 && ring[0][16] == 4);
    show(0); assert(snapshot[0][0] == 1);
    for (i=0; i<64; i++) {
        p[0]= i%2 ? 8 : 1;
        rxts_diag_record(p, 64, &ts, 41, 7050, 8000);
    }
    assert(total == 65 && count == 32);
    assert(snapshot_count == 1 && snapshot[0][0] == 1);
    show(1); assert(snapshot_count == 1 && snapshot[0][0] == 1);
    show(0); assert(snapshot_count == 32 && snapshot[0][0] == 34);
    for (i=0; i<8; i++) show(i);
    assert(snapshot[31][0] == 65 && snapshot_total == 65);
    puts("RXTS_NATIVE=PASS input-immutable filter packing ring-wrap frozen-pages bounded-output");
    return 0;
}
