# Step5 source audit

- Branch: `exp/step5-softpll-lock`
- Baseline: `main@a89b2df`
- Scope: read-only observability and evidence collection
- Functional code changed in this audit: none

## Call/control path

```text
WR LOCK / WRS_S_LOCK
  -> vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c
       wrpc_spll_locking_enable()
       -> spll_init(SPLL_MODE_SLAVE, 0, SPLL_FLAG_ALIGN_PPS)
  -> vendor/wrpc-sw/softpll/softpll_ng.c
       spll_init() -> SEQ_CLEAR_DACS
       -> SEQ_START_HELPER -> SEQ_WAIT_HELPER
       -> helper_update() / helper lock detector
       -> SEQ_START_MAIN -> SEQ_WAIT_MAIN
       -> mpll_update() / frequency and phase lock detectors
       -> SEQ_READY
  -> vendor/wrpc-sw/lib/task-diags.c
       periodic read-only WDIAGS shadow update
  -> scripts/jtag/read_wb_runtime.tcl
       same-session before/after decode
  -> scripts/jtag/read_wb_timeseries_session.tcl
       same-session time-series observation
```

## Signal mapping

| Signal / field | Source file and symbol | WB address / bitfield | Meaning | Step5 use |
|---|---|---|---|---|
| `PSTAT.locked` | `vendor/wrpc-sw/include/hw/wrc_diags_regs.h`, `WRC_DIAGS_WDIAG_PSTAT_LOCKED`; written by `wdiags_write_pstat()` | `0x00100A0C[1]` | upper WR lock result | required supporting result; not sufficient alone |
| `SPLL_MODE` | `vendor/wrpc-sw/softpll/softpll_ng.c`, `softpll.mode`; packed in `task-diags.c` | `0x00100AA0[23:16]` | current SoftPLL mode | context; Slave expects `3` |
| `SPLL_SEQ_STATE` | `softpll_ng.c`, `softpll.seq_state`; packed in `task-diags.c` | `0x00100AA0[7:0]` | sequencer state | localizes startup vs helper/main boundary |
| `SPLL_DELOCK_COUNT` | `softpll_ng.c`, `softpll.delock_count`; packed in `task-diags.c` | `0x00100AA0[31:24]` | number of return-to-clear-DAC events | delock evidence |
| `HELPER_LOCKED` | `softpll_ng.c`, `softpll.helper.ld.locked`; packed in `task-diags.c` | `0x00100ABC[0]` | helper lock detector currently locked | required helper lock |
| `HELPER_LOCK_CHANGED` | `softpll_ng.c`, `softpll.helper.ld.lock_changed`; packed in `task-diags.c` | `0x00100ABC[1]` | helper detector changed in latest update | acquisition/loss edge context; not stable proof |
| `HELPER_REF_SRC` | `softpll_ng.c`, `softpll.helper.ref_src`; packed in `task-diags.c` | `0x00100ABC[15:8]` | helper reference channel | source consistency |
| `HELPER_LOCK_COUNT` | `softpll_ng.c`, `softpll.helper.ld.lock_cnt`; packed in `task-diags.c` | `0x00100ABC[31:16]` | in-range sample count | progress toward helper lock |
| `HELPER_THRESHOLD` | `softpll_helper.c`, `s->ld.threshold`; packed in `task-diags.c` | `0x00100AC0[15:0]` | acceptable helper error magnitude | decode/denominator |
| `HELPER_LOCK_SAMPLES` | `softpll_helper.c`, `s->ld.lock_samples`; packed in `task-diags.c` | `0x00100AC0[31:16]` | required consecutive helper samples | decode/denominator |
| `MAIN_ENABLED` | `softpll_ng.c`, `softpll.mpll.enabled`; packed in `task-diags.c` | `0x00100AC4[0]` | main PLL started | required before main lock interpretation |
| `MAIN_LOCKED` | `softpll_ng.c`, `softpll.mpll.locked`; packed in `task-diags.c` | `0x00100AC4[1]` | main PLL final lock result after gain schedule | required main result |
| `MAIN_FREQ_LOCKED` | `softpll_main.c`, `softpll.mpll.freq_ld.locked`; packed in `task-diags.c` | `0x00100AC4[2]` | frequency detector lock | required intermediate main result |
| `MAIN_PHASE_LOCKED` | `softpll_main.c`, `softpll.mpll.phase_ld.locked`; packed in `task-diags.c` | `0x00100AC4[3]` | phase detector lock | required final main result |
| `MAIN_FREQ_LOCK_COUNT` | `softpll_main.c`, `softpll.mpll.freq_ld.lock_cnt`; packed in `task-diags.c` | `0x00100AC4[19:8]` | frequency in-range sample count | progress toward frequency lock |
| `MAIN_PHASE_LOCK_COUNT` | `softpll_main.c`, `softpll.mpll.phase_ld.lock_cnt`; packed in `task-diags.c` | `0x00100AC4[31:20]` | phase in-range sample count | progress toward phase lock |
| `MAIN_FREQ_THRESHOLD` | `softpll_main.c`, `s->freq_ld.threshold`; packed in `task-diags.c` | `0x00100AC8[15:0]` | acceptable frequency error | decode/denominator |
| `MAIN_FREQ_LOCK_SAMPLES` | `softpll_main.c`, `s->freq_ld.lock_samples`; packed in `task-diags.c` | `0x00100AC8[31:16]` | required consecutive frequency samples | decode/denominator |
| `MAIN_PHASE_THRESHOLD` | `softpll_main.c`, `s->phase_ld.threshold`; packed in `task-diags.c` | `0x00100ACC[15:0]` | acceptable phase error | decode/denominator |
| `MAIN_PHASE_LOCK_SAMPLES` | `softpll_main.c`, `s->phase_ld.lock_samples`; packed in `task-diags.c` | `0x00100ACC[31:16]` | required consecutive phase samples | decode/denominator |

## Source semantics

`softpll_ng.c` shows that a Slave only enters `SEQ_START_MAIN` after the helper
lock detector reports a lock transition. `mpll_update()` then updates frequency
lock first; phase lock is evaluated only after frequency lock, and
`mpll_handle_gain_schedule()` promotes `softpll.mpll.locked` only after the
configured gain schedule completes. Therefore a sample showing helper lock but
`SEQ_WAIT_MAIN` is an active startup boundary, not a Step5 failure.

`spll_common.c::ld_update()` defines lock acquisition as `lock_cnt` reaching
`lock_samples` while the absolute error remains within `threshold`. Loss uses
the source-defined `delock_samples` hysteresis. A long observation must therefore
track both lock bits and `SPLL_DELOCK_COUNT`; a single value cannot prove stable
lock.

## PASS suitability

The first Step5 run is a baseline and must not emit `STEP5_RESULT = PASS`. It
should report the first inactive boundary and preserve all raw source-backed
fields. A future formal Step5 PASS requires, at minimum:

1. Step1–4B upstream gates are established in the same run.
2. Helper lock, main frequency lock, main phase lock, main final lock, and
   `PSTAT.locked` are all observed.
3. No lock loss is observed and `SPLL_DELOCK_COUNT` does not increase.
4. The required long-duration stability window is complete and documented.

Any unmapped or aliasing value is `SOURCE_SEMANTICS_NOT_PROVEN`, not a failure
claim. The firmware commit, RTL/SOF identity, and Tcl decoder commit must remain
fixed in each experiment record.

