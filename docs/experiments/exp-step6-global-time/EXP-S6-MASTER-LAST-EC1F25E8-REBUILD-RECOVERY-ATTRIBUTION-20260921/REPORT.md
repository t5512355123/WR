# EXP-S6-MASTER-LAST-EC1F25E8-REBUILD-RECOVERY-ATTRIBUTION-20260921

## Verdict

```text
RESULT                         = INCONCLUSIVE_OBSERVER_RUNTIME_ERROR
MASTER_SOURCE_REBUILD          = PASS
MASTER_FIRMWARE_BUILD          = PASS
MASTER_FULL_COMPILE            = PASS
MASTER_PROGRAM_COUNT           = 1
SLAVE_PROGRAM_COUNT            = 0
POWER_CYCLE                    = 0
MASTER_LOCAL_READY             = NOT_EVALUATED
SLAVE_RECOVERY                 = NOT_EVALUATED
STARTUP_ORDER_SENSITIVITY      = NOT_DETERMINED
STEP6A_GLOBAL_TIME             = NOT_PASS
STEP6B_SCHEDULED_TRIGGER       = NOT_RUN
```

The rebuild and the single Master programming operation completed
successfully.  The paired recovery observer started immediately but crashed
before its first sample because of an observer Tcl regexp bug.  Therefore this
run provides no valid post-program recovery verdict and must not be called a
recovery pass or fail.

## Build provenance

```text
SOURCE_COMMIT       = ec1f25e81e0eb8c2caee796d13a225eaae81e5f2
SOURCE_TREE         = clean detached worktree at ec1f25e8
MASTER_VHDL_SHA256  = 52d402002b7804a89545448c2e32ecedf360969636b52595692f58727dfdc8f7
MASTER_QSF_SHA256   = f434c9b7e0ecfcc2378e0c1c5966762328e04ce6fc63f3cede4a77ccfb8c7607
MASTER_SDC_SHA256   = 083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d
MASTER_MIF_SHA256   = 8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e
MASTER_SOF_SHA256   = c5de071d88fff6e4bf2b0e38dccebd7100daadd2629834589a2eb64e17834969
QUARTUS             = Prime 17.0 Build 595
TIMING_CLOSED       = NO (recorded only; not a gate)
```

The full Quartus log ends with `0 errors` and `298 warnings`; fitter and
assembler produced the SOF.  The new SOF is intentionally not identified as
the lost original `568f08...` artifact.

## Pre-program baseline

Five paired read-only samples passed before touching Master:

```text
BASELINE_RESULT                 = PASS
BASELINE_SLAVE_LINK_MODE       = UP
BASELINE_SLAVE_LINK_UP_COUNT   = 5/5
MASTER_BASIC_READY              = PASS
SLAVE_BASIC_READY               = PASS
SLAVE_RX_LOCKED_TO_DATA        = 1
SLAVE_RX_ACTIVITY              = changing
MASTER/SLAVE reset signatures   = stable
```

The last baseline sample recorded `PTP_STATE=6` on Master and `PTP_STATE=9`
on Slave, with both `CORE_LINK_OK` and `CORE_TM_LINK_UP` equal to 1.  Slave
sticky counters were preserved in `raw/baseline/baseline.log` for the required
pre/post drop comparison.

## Programming and observer timing

```text
Target                         = DE5 [1-11.1]
Master programming             = exactly once
Program result                 = 1 device configured, 0 errors
Slave programming              = not performed
Program done → observer start  = 5 ms
First valid recovery sample    = none
```

The complete programmer output is in `raw/program/master-program.log`; the
sequence timestamps are in `raw/program/sequence-times.log`.

## Observer failure

The recovery reader reached its configuration line, then stopped before any
`REBUILD_RECOVERY_PAIR` sample:

```text
invalid command name "^"
procedure: rb_baseline_scalar
cause: Tcl regexp character-class brackets were interpreted as command substitution
```

This is an instrumentation failure, not evidence that the Slave failed to
recover.  No second Master program, Slave program, reset, power cycle, or
control write was performed.

The Tcl reader was corrected after the run to build its dynamic patterns with
`format { ... }`, avoiding command substitution.  That correction was not
used to reinterpret this capture; a new hardware run requires a new adviser
approval and a new programming event.

## Files

```text
PLAN.md
REPORT.md
raw/build/*
raw/baseline/baseline.log
raw/program/*
raw/recovery/recovery.log
analysis/summary.json
```

