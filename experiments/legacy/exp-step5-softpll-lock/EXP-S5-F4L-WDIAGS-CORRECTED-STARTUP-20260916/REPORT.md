# F4L WDIAGS-Corrected Startup Report

## Verdict

This run is a valid partial, passive diagnostic capture, but it is not a
completed F4L diagnostic and it is not a Step5 result. The observer reached
the real White Rabbit session terminal condition before the 120-second formal
window could complete. The data is sufficient to show that the Slave Main
producer was active while Helper remained locked, but it is not sufficient to
claim a gain or control-causality result.

```text
STEP5_PASS          = NO
DIAGNOSTIC_PASS     = NO
DIAGNOSTIC_COMPLETE = NO
MERGE_APPROVED      = NO
RUN_END_REASON      = STOP_WR_SESSION_ENDED
STOP_REASON         = WR_SESSION_ENDED
```

## Reproducibility identity

```text
source_commit        = 68545617be4f2de781269ed6588f984557be2318
source_branch        = exp/step5-softpll-lock
experiment           = EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260916
hardware_role        = Master DE5 [1-11.1], Slave DE5 [1-11.2]
quartus              = 17.0 Build 595
observer_mode        = read-only
one_reader           = 1
no_control_write     = 1
no_helper_pi_snapshot= 1
no_debug_fifo_drain  = 1
no_rtl_or_sdb_change = 1
```

The only source change for this run was an observer control-flow correction:
F4L's no-valid timeout was widened to 30 seconds and the smoke coverage
deadline to 60 seconds, so a slow but valid diagnostic producer was not
declared failed at the old 10-second boundary. No production C/RTL control
parameter or control branch was changed.

## Build and programming

Pain pulled the exact source commit before compiling. Both clean Quartus
compilations succeeded and both intended boards were programmed successfully.
The full build, program, source hashes, and raw logs are preserved below
`raw/build/` and `raw/`.

```text
Master GIT_COMMIT = 68545617be4f2de781269ed6588f984557be2318
Slave  GIT_COMMIT = 68545617be4f2de781269ed6588f984557be2318
Master MIF SHA256  = ca01aaa884feca6b9caa9cb58cb521b3568b06d0772cf0f46035e386e99e8c87
Slave  MIF SHA256  = 91c0946aa0e3a4d07870145fc6dee9162251d9f66e5176da314c62d41ab2ac7a
Master SOF SHA256  = 3e294cc085b3c710835f98cf036db31c503b7e91305a8fea54fad1a7ac6773e1
Slave  SOF SHA256  = 5af58409244dbf0a49846d6b4edc80a7d8e0a33f4957d562debd23bd095d1db1
Master timing      = TIMING_CLOSED=NO, WNS=-0.047 ns
Slave  timing      = TIMING_CLOSED=NO, WNS=-0.268 ns
```

The corrected WDIAGS mapping preflight passed on both boards. Its raw log and
checksum are preserved as `raw/wdiags-preflight.log` and the corresponding
Pain-side session artifact.

## Capture protocol and termination

The observer was run as one read-only JTAG reader after the programmed images
settled:

```text
target_duration_ms = 120000
hard_duration_ms   = 130000
smoke_deadline_ms  = 60000
no_valid_timeout_ms = 30000
```

The session ended after 40.524 seconds because the Slave reported the actual
WR S_LOCK timeout. This was not a JTAG mapping or transport failure:

```text
WDIAGS preflight       = PASS
F4L valid frames       = 15/15
F4L unique frames      = 15/15
F4L transport errors   = 0
F4L semantic problems  = 0
run_end_reason         = STOP_WR_SESSION_ENDED
last terminal          = 1
last WR_FAILURE_REASON = 3
last PSTAT_LOCKED      = 0
```

The Master side produced no valid F4L frames before the shared session ended.
The Slave side produced 15 unique valid frames over a 39.810-second source
span: page 0 occurred 8 times, page 1 occurred 7 times, and page 2 did not
occur. Therefore the histogram page required for full F4L coverage is absent.

## Hardware observations

Every retained Slave cycle had a valid Main diagnostic frame and a valid WR
core/PHY state. Helper was reported locked in all 15 cycles. Main update IDs
advanced across all 14 adjacent intervals, and no retained cycle showed
Helper unlocked while Main was valid. Helper residual was present in 11 of the
15 valid rows; its normal request/completion counters advanced, but the
existing cross-domain snapshot does not prove same-cycle admission causality.

At the final retained cycle:

```text
HELPER_LOCKED       = 1
MAIN_F4L_VALID      = 1
WR_CORE_VALID       = 1
PHY_LINK_USABLE     = 1
PSTAT_LOCKED        = 0
TERMINAL            = 1
WR_STATE            = 0
BOOT_GENERATION     = 1
CPU_RESET_COUNT     = 1
WR_CORE_RESET_COUNT = 0
SI_CONFIG_DROP_COUNT= 0
```

The stable generation and reset fields show no new boot-generation, WR-core,
or SI configuration reset during the retained window. The terminal state is
nevertheless authoritative: Step5 did not lock before the WR deadline.

## Offline F4L analysis

The raw log was replayed with
`scripts/experiment/step5_f4l_main_phase_drift_integrator.py`; the result is
`analysis/f4l-verdict.json`.

```text
classification              = DIAGNOSTIC_STOPPED_WR_SESSION_ENDED
frame_count                 = 15
invalid_frame_count         = 0
unique_count                = 15
generations                 = [1]
main_progress_intervals     = 14
helper_unlocked_with_main   = 0
helper_residual_with_main   = 11
page0/page1/page2            = 8/7/0
valid_10s_bins               = 5
diagnostic_complete          = false
step5_pass                  = false
```

The available page-0 window contained 146,758 phase updates, with 19,947
in-band and 126,811 out-of-band updates (approximately 13.6% in-band). The
phase-conditioned frequency-error sum was positive (`6,884,829`) while the
modulo phase-delta sum was negative (`-6,884,372`), with 420 positive and no
negative boundary-crossing proxies. These are consistent with a possible
one-sided modulo drift pattern, but the adjacent differences are only a
modulo-crossing proxy; they are not proof of physical cycle slips.

The available page-1 window reported frequency and phase actual-integrator
deltas of `-5,034,460` and `+4,650,905`, respectively. The proposed `Ki*x`
totals matched those actual deltas, with zero clamp events, zero anti-windup
events, and zero accounting mismatches in that page window. Because page 0 and
page 1 are separate non-atomic publications and page 2 is absent, these
numbers must not be combined into a same-iteration causal claim.

## Interpretation and next boundary

This run supports the following limited conclusion:

> Main phase acquisition was active and continued producing updates while the
> Helper was locked, yet the phase remained mostly outside the lock band and
> the WR session reached S_LOCK timeout. The evidence suggests a residual
> phase/frequency drift or acquisition problem, but does not identify whether
> the cause is Ki balance, actuator response, handoff timing, reference/sign,
> or another control-path issue.

It does not support changing Kp/Ki, threshold, timeout, bootstrap, arbitration,
DAC, RTL, or reset behavior from this capture alone. F4L is therefore recorded
as `DIAGNOSTIC_STOPPED_WR_SESSION_ENDED`, Step5 remains `NO`, and no merge is
approved.

The next experiment must first close the missing evidence boundary: capture
the first-loss/S_LOCK deadline and the complete F4L page rotation in one
generation, or explicitly record why the page-2 producer cannot publish before
the deadline. Any later single control change must be based on a completed,
same-generation diagnostic window rather than this partial capture.

