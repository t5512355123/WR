# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-004F439-HELPER-LOCK-CONVERGENCE-600S-20260902

## Purpose

This is the next controlled experiment selected by branch5 after reviewing
the latest branch head. It tests whether the currently programmed
`004f439` frozen-fit image can reproduce and sustain the Helper lock gate.
It is a runtime observability run only; it does not claim Step5 completion by
itself.

## Branch5 handoff

The latest branch5 review of `84c5dfb` states:

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
```

The required next experiment is this 600-second Helper convergence run on the
same `004f439` frozen-fit Master/Slave images already programmed on pain.

## Controlled conditions

```text
source firmware revision       = 004f4396f48622ded3575fcf11aa9a906f571c65
fitted database                = current frozen-fit database
placement/routing              = unchanged
bootstrap                      = 6208
code_per_physical_step         = 16
helper kp / ki                 = -300 / -1
helper threshold               = 200
helper lock samples            = 10000
QSFPA lane                     = 2
normal tracker                 = ON
control-variable change        = NONE
rebuild/recompile              = NO
reprogram                      = NO
```

The only local repository change for this run is this experiment record. No
functional firmware, controller, FPGA, or diagnostic observer source is
changed.

## Required observer command

```text
quartus_stp -t scripts/jtag/read_step5_hpll_lock_convergence.tcl 6000 100 "DE5 [1-11.2]"
```

This gives a nominal 6000-sample, 100-ms observation window (`599.9 s` from
the first to the last scheduled sample). The observer is read-only and does
not write WR configuration, HPLL force controls, or DATA_SNAPSHOT.

## Acceptance gates

The raw log must preserve the final summary for:

```text
SAMPLES
VALID_FRAMES / INVALID_FRAMES
HELPER_LOCK_COUNT_MAX
HELPER_LOCK_COUNT_FINAL
HELPER_LOCKED_EVER / HELPER_LOCKED_FINAL
MAIN_ENABLED_EVER / MAIN_ENABLED_FINAL
MAIN_FREQ_LOCKED_FINAL
MAIN_PHASE_LOCKED_FINAL
MAIN_LOCKED_FINAL
PSTAT_LOCKED_FINAL
SPLL_DELOCK_COUNT_DELTA
RESET deltas
```

This run can at most establish Helper-lock progress or a negative Helper-lock
result. Step5 is not PASS unless the complete branch5 lock criteria are met,
including the downstream Main/phase/PSTAT chain and the required continuous
stability evidence.

## Pre-run status

```text
PREFLIGHT_RESULT          = PASS (3 consecutive settled captures)
STEP4B_COMPLETE           = YES
STEP4B_REVALIDATED        = YES FOR 004F439 IMAGE
STEP5_COMPLETE            = NO
MERGE_APPROVED            = NO
RUN_RESULT                = PENDING
```

## Raw evidence

The completed observer log and any pre-run verification log will be stored
under:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-004F439-HELPER-LOCK-CONVERGENCE-600S-20260902/`
