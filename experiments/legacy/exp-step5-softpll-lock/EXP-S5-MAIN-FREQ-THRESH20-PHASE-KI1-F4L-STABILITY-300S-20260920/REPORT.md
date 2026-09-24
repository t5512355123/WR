# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920

日期：2026-09-20（Asia/Taipei）

## Verdict

```text
STEP5_FUNCTIONAL_PASS             = PASS
STEP5_PASS_MILESTONE              = ESTABLISHED
STEP5_FOUR_LOCKS_300S             = PASS
HELPER_HPLL_LOCK                  = PASS (316/316 cycles)
MAIN_FREQUENCY_LOCK               = PASS (316/316 frames)
MAIN_PHASE_LOCK                   = PASS (316/316 frames)
PSTAT_LOCK                        = PASS (316/316 cycles)
FULL_CHAIN_MAX_SECONDS            = 300.321
FULL_CHAIN_300S                   = 1
TIMING_CLOSED                     = NO (not a functional gate)
F4L_STRICT_SCHEMA                 = CAVEAT (4 repeated page-accounting rows)
```

This is the first recorded same-session capture that reaches the required
300-second window while retaining all four functional lock conditions. The
timing result is reported honestly but does not invalidate this functional
milestone, per the current project policy.

## Exact provenance

```text
firmware/source commit             = 26e138fdc0bfc8426704b397141d563cf4d580a2
observer-contract commit           = 47d9a394e53eda31476c82de2a85ad82573494ed
Pain worktree firmware HEAD        = 26e138fdc0bfc8426704b397141d563cf4d580a2
Quartus                           = 17.0.0 Build 595
Master SOF SHA256                 = a2945df48fe86038fdff138f4b6368a777fa3df13f98ac9620fb30baa1ee0129
Slave SOF SHA256                  = 7462d94a521f52e7660295a6873de5141658fbf5392d90a4d4ade7d4e5f36f50
Master MIF SHA256                 = b1e65e19dbcee7f718d93eab72f9469b734be7065e404b56676dca56d9ff4efb
Slave MIF SHA256                  = 1fe50c67ac75354034fbe11c7db0924ade8a8f1ef2fa3d782c4f78c1eca75ab0
Master QSF SHA256                 = f434c9b7e0ecfcc2378e0c1c5966762328e04ce6fc63f3cede4a77ccfb8c7607
Slave QSF SHA256                  = 99851099c786f14ebbdc91949c9f2caaa8b0679273df7703c1a0e6a4a3aaf5f2
Shared SDC SHA256                 = 921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b
```

The build results were successful with zero Quartus errors. Timing metadata
was `Master WNS=-0.289 ns` and `Slave WNS=-0.361 ns`; these are retained as
implementation caveats only.

## Hardware procedure

Master was programmed first to `DE5 [1-11.1]`, followed by Slave on
`DE5 [1-11.2]` after the prescribed settling interval. Both programmer logs
reported one device configured and zero errors. After more than 120 seconds,
the read-only preflight confirmed the link, endpoint/PTP activity, trusted
JTAG/WB transport, Helper state, Main state, and PSTAT state. The dashboard
also emitted the known WR signal sideband read-inconsistent classification;
source-backed link/reset/SoftPLL state remained healthy and the F4L reader
validated the same fields every cycle.

The first F4L attempt is preserved as a non-evidence diagnostic artifact:
the old observer hard cap ended it at `120018 ms` despite a 300-second
invocation. The observer-only contract was then corrected and pushed in
`47d9a394`; Pain fetched that change without changing or reprogramming the
firmware image.

## Formal 300-second capture

Command:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 300000 310000 f4l
```

```text
quartus_exit                       = 0
run_end_reason                     = TARGET_REACHED
stop_reason                        = NONE
session_elapsed_ms                 = 300321
slave_cycles                       = 316
master_samples                     = 80
diag_valid                         = 316
diag_unique                        = 159
page0/page1/page2                  = 105/105/106
single_reader                      = PASS
```

Raw capture:

```text
raw/f4l_threshold20_phase_ki1_stability_300s_retry.log
SHA256 = a03e66b2efb2161250b5266875338fd1f8d6ca3dd3221bff0d355d8f27ab9b72
```

## Four-lock evidence

The observer-level lock audit is in
[`analysis/lock-audit.md`](analysis/lock-audit.md). The result is:

| Gate | Evidence | Result |
|---|---:|---|
| Helper/HPLL lock | `HELPER_LOCKED=1` on 316/316 Slave cycles; `HELPER_STATE_RAW=03E80001` | PASS |
| Main frequency lock | `BRANCH_ID=2`, `FLAGS=383`, frequency-lock-after bit on 316/316 frames | PASS |
| Main phase lock | phase-lock-before/after and phase-called/in-band bits on 316/316 frames | PASS |
| PSTAT lock | `PSTAT_LOCKED=1` on 316/316 Slave cycles | PASS |

`FLAGS=383 (0x17F)` is decoded from the checked-in
`vendor/wrpc-sw/softpll/spll_main_diag.h`; it contains valid, frequency lock
before/after, phase lock before/after, phase-detector-called, phase-in-band,
and DAC-write bits, with phase-out-of-band clear.

## Session health

Across all 316 Slave cycles:

```text
PHY_LINK_USABLE                     = 316/316
TERMINAL=0                          = 316/316
TERMINAL_FRESH_EDGE=0              = 316/316
RESET_CHANGED=0                     = 316/316
BOOT_GENERATION                     = 1 (stable)
CPU_RESET_COUNT / WR_CORE_RESET    = stable
SI_CONFIG_DROP_COUNT               = 0 delta
SPLL_DELOCK_COUNT                  = 0
```

F4L page accounting also showed nonzero phase Ki1 activity:

```text
phase_i_count_delta                 = 1130614
phase_actual_i_sum_delta            = 952333
phase_ki_x_sum_delta                = 952333
actual_delta_mismatch_delta         = 0
clamp_event_count_delta             = 0
anti_windup_event_count_delta       = 0
```

## Data-quality caveat

The strict offline F4L analyzer output is preserved at
`analysis/f4l_300s_analysis.json`. It classified four rows as
`HISTOGRAM_PHASE_COUNT_MISMATCH`/`SUMMARY_PHASE_COUNT_MISMATCH`: two repeated
observations at cycles 50/51 and two at 274/275. They are repeated page
identities rather than a lock-bit loss, and each still contains `FLAGS=383`.
The observer-level four-lock audit therefore passes, while this page-level
accounting caveat remains explicitly attached to the milestone. No raw row
was deleted or rewritten.

## Conclusion

The `threshold20 + phase-Ki1` candidate is now the Step5 functional PASS
milestone: Helper/HPLL lock, Main frequency lock, Main phase lock, and
`PSTAT.locked` were all retained for more than 300 seconds in one valid WR
session. Timing closure remains open and is intentionally tracked as a
separate implementation task.
