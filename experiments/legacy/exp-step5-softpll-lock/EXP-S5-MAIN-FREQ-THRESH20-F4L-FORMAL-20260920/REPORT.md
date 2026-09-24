# EXP-S5-MAIN-FREQ-THRESH20-F4L-FORMAL-20260920

## Verdict

```text
F4L_THRESH20_FORMAL_CAPTURE = PASS
F4L_DIAGNOSTIC_ANALYSIS     = PASS
THRESH20_DIRECTION          = MIXED
MAIN_PHASE_LOCK_OBSERVED    = NO
STEP5                       = NO
```

The advisor-approved 120-second threshold20 F4L formal capture completed
normally in the existing live session.  It is a valid passive diagnostic
capture, not a Step5 lock proof.

## Provenance and procedure

```text
FPGA/source image commit       = 00d7572fa4943dbba1e28b2245f884fc04386a94
formal plan commit             = 70b9ad0e
previous Main gate report      = b4b3ae4a
Slave main limits              = 00320014
Master main limits             = 00320032
F4L diagnostic owner           = enabled in the programmed image
control writes                 = none
reprogram/reset/power-cycle   = none
reader processes               = 1
raw log SHA256                 = 1b8e9e3983dec8f60dff87bcfb65ea1dae316e6b9466cfba86ce3cc6f32dcad5
```

Command:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  2400 100 "" 120000 130000 f4l
```

The command was captured from the first line with `tee`.  The observer's
embedded `EXPERIMENT` label still contains the earlier F4L source label
`EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260919`; the folder, plan,
command, source provenance, and checksum identify this formal run.

## Formal stop and validity checks

```text
quartus_exit                 = 0
run_end_reason               = TARGET_REACHED
stop_reason                  = NONE
session_elapsed_ms           = 120283
target_duration_ms           = 120000
hard_duration_ms             = 130000
smoke_ok                     = 1
```

The Slave F4L stream contained:

```text
MAIN_F4L_VALID               = 127 / 127 cycles
invalid frames               = 0
unique coherent frames      = 64
unique span                 = 119582 ms
10-second validity bins     = 13
page 0 / page 1 / page 2    = 42 / 43 / 42
semantic problems           = none
Main progress intervals     = 63
```

The 64 unique frames covered all three pages.  The Master WR-core sampling
completed 32 samples; the formal F4L frame stream used for the normalized
analysis is the Slave Main stream.

## Runtime health

Across the capture, the runtime guards remained healthy:

```text
Helper locked               = 1 on every valid cycle
Helper unlocked with Main   = 0 cycles
PHY_LINK_USABLE             = 1
PSTAT_LINK                  = 1
BOOT_GENERATION             = 1 (stable)
WR_CORE_RESET_COUNT         = 0 (stable)
SI_CONFIG_DROP_COUNT        = 0 (stable)
RESET_CHANGED               = 0
SPLL_DELOCK_COUNT           = 0
TERMINAL                    = 0
TERMINAL_FRESH_EDGE         = 0
WR_FAILURE_REASON           = 3 (historical sticky value only)
```

The observer's schedule sideband was not available in this capture:
`SCHEDULE_VALID=0` and `MAIN_STATE_RAW=INVALID` in the F4L cycle records.
This prevents any schedule-side claim.  It does not invalidate the F4L core
frames: the coherent Main frame was valid and its `TOTAL_UPDATES` advanced
throughout the capture.

## Normalized result

The complete arithmetic is in
`analysis/normalized-comparison.md`.  Relative to the frozen threshold50/Ki=0
baseline:

```text
mean residual frequency       43.989818 -> 10.358250  (-76.4531%)
mean phase drift magnitude    43.985382 -> 10.358036  (-76.4512%)
boundary crossing rate          0.268501% -> 0.128861% (-52.0074%)
phase in-band ratio             13.439280% -> 10.465809% (-2.9735 pp)
```

The unique F4L frames stayed in the phase branch (`BRANCH_ID=2`, 64/64), with
no observed frame-level FREQ-to-PHASE or PHASE-to-FREQ transitions.  The
page-0 counters also showed zero frequency updates and 434,577 phase updates
over their independent window.  The page-1 integrator counters showed
nonzero phase-update count but zero phase actual-I sum and zero phase Ki-X sum;
clamp, anti-windup, and actual-delta mismatch counters remained zero.

This supports a strong threshold20 effect on residual error and drift, but the
opposite phase in-band movement means the causal result is mixed.  It does not
show that threshold20 alone produces closed-loop phase lock.

## Step5 conclusion

Step5 remains `NO`:

```text
PSTAT_LOCKED              = 0
MAIN_PHASE_LOCKED         = 0 in the admitted runtime state
stable phase-lock interval = not observed
```

The capture also does not remove the existing timing caveat from the clean
build (`Slave WNS=-0.361 ns`, `Master WNS=-0.289 ns`), so complete Step5
PASS cannot be declared even if a later functional lock interval is observed
without timing closure.

No follow-up hardware run, control change, threshold sweep, reprogramming, or
merge action was performed after this formal capture.  The next decision is
deferred to the phase-lock advisor after reviewing this report.
