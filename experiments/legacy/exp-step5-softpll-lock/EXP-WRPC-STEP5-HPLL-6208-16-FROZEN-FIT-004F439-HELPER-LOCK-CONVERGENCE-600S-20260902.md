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
RUN_RESULT                = COMPLETED_NEGATIVE
```

## 600-second Helper convergence result

The observer completed normally on Slave `DE5 [1-11.2]`:

```text
SAMPLES                       = 6000
VALID_FRAMES                  = 6000
INVALID_FRAMES                = 0
WINDOW_SECONDS                = 599.901
HELPER_LOCK_COUNT_MAX         = 2
HELPER_LOCK_COUNT_FINAL       = 2
HELPER_LOCKED_SEEN            = 0
HELPER_LOCKED_FINAL           = 0
FIRST_HELPER_LOCK_SAMPLE      = NONE
HELPER_ERROR_MEAN             = 150000.0
HELPER_ERROR_RMS              = 150000.0
HELPER_ERROR_MAX_ABS          = 150000
HELPER_ERROR_FRACTION_LE_200  = 0.0
HELPER_OUTPUT_RAIL5_FRACTION  = 100.0
MAIN_ENABLED_FINAL            = 0
MAIN_FREQ_LOCKED_FINAL        = 0
MAIN_PHASE_LOCKED_FINAL       = 0
MAIN_LOCKED_FINAL             = 0
PSTAT_LOCKED_FINAL            = 0
SPLL_DELOCK_COUNT_DELTA       = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_BOOT_GENERATION_DELTA   = 0
RESET_CPU_DELTA               = 0
RESET_WR_CORE_DELTA            = 0
RESET_SI_CONFIG_DELTA         = 0
```

The run therefore closed the Helper-lock question for this exact image and
control condition: the Helper lock gate was not reached. The first inactive
Step5 boundary remains `HELPER_LOCK`; Main and PSTAT results are not
interpretable as downstream failures because `MAIN_ENABLED` never became 1.

## Final judgement

```text
STEP4B_COMPLETE           = YES
STEP4B_REVALIDATED        = YES FOR 004F439 IMAGE
STEP5_COMPLETE            = NO
STEP5_RESULT              = NEVER_LOCKED
STEP5_FIRST_INACTIVE      = HELPER_LOCK
MERGE_APPROVED            = NO
```

This is not merge evidence. The next experiment remains subject to the
branch5 review of this completed raw result.

## Raw evidence

The completed observer log and any pre-run verification log will be stored
under:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-004F439-HELPER-LOCK-CONVERGENCE-600S-20260902/`
