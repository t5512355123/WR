# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-FIRMWARE-BISECTION-HELPER-CONVERGENCE-600S-20260902

## Purpose

This experiment is the firmware bisection selected by branch5 after reviewing
the completed `004f439` Helper convergence run. It tests whether the next
firmware-changing boundary, `88604a5`, restores Helper lock while keeping the
FPGA implementation and all runtime control conditions fixed.

## Branch5 handoff

The latest branch5 review of `13073f7` states:

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
```

The required next experiment is the exact `004f439 -> 88604a5` firmware
bisect. The `88604a5` source revision is:

```text
88604a5ca174fd3b36b0a8eb435ec1773dd061a3
fix: serialize Main diagnostic overlay ownership
```

## Single controlled variable

```text
ONLY_CONTROL_VARIABLE = WRPC_FIRMWARE_REVISION
baseline              = 004f439
test                  = 88604a5
```

All other conditions remain fixed:

```text
fitted database                = same current frozen-fit database
placement/routing              = unchanged
bootstrap                      = 6208
code_per_physical_step         = 16
helper kp / ki                 = -300 / -1
shift / bias                   = 12 / 5
helper threshold               = 200
helper lock samples            = 10000
QSFPA lane                     = 2
normal tracker                 = ON
```

## Required build and programming method

1. Build only the Master and Slave WRPC firmware MIFs from the immutable
   `88604a5` source revision.
2. Apply those MIFs to the same fitted database using `update_mif` plus
   assembler only.
3. Do not run synthesis, fitter, place-and-route, HDL changes, or controller
   parameter changes.
4. Preserve and compare the four fit/STA hashes against the frozen baseline.
5. Program Slave first and Master second.
6. Require three consecutive settled preflight captures before the 600-second
   observer.

The generated SOF hashes are expected to differ from `004f439`; the fit/STA
hashes must remain identical.

## Preflight gate

Every settled capture must show:

```text
Master Step1/2/4A        = PASS
Slave Step1/2/3/4B       = PASS
STEP4B_ALLOWED           = YES
STEP4B_RESULT            = PASS
RXERR_DELTA              = 0
all reset deltas         = 0
JTAG_WB_DIAGNOSTIC_PATH  = TRUSTED
```

If this gate fails, stop and do not run the 600-second Helper observer.

## Helper convergence gate

Only after three settled preflight passes, run:

```text
quartus_stp -t scripts/jtag/read_step5_hpll_lock_convergence.tcl 6000 100 "DE5 [1-11.2]"
```

The raw log must preserve:

```text
SAMPLES / VALID_FRAMES / INVALID_FRAMES / WINDOW_SECONDS
HELPER_LOCK_COUNT_MAX / HELPER_LOCK_COUNT_FINAL
HELPER_LOCKED_EVER / HELPER_LOCKED_FINAL
MAIN_ENABLED_FINAL
MAIN_FREQ_LOCKED_FINAL / MAIN_PHASE_LOCKED_FINAL / MAIN_LOCKED_FINAL
PSTAT_LOCKED_FINAL
SPLL_DELOCK_COUNT_DELTA
NORMAL_TRANSACTION_ACCOUNTING
all reset deltas
```

The 600-second result is still not Step5 PASS unless the complete downstream
lock chain and the required continuous stability criteria are demonstrated.

## Pre-run status

```text
BASELINE_RESULT_004F439 = TRUSTED_HELPER_NO_LOCK
BASELINE_HELPER_LOCK_COUNT_MAX = 2
STEP4B_COMPLETE           = YES
STEP4B_REVALIDATED        = YES
STEP5_COMPLETE            = NO
MERGE_APPROVED            = NO
RUN_RESULT                = PENDING
```

## Raw evidence

The build, MIF-only assembly, programming, preflight, and Helper observer logs
will be stored under:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-FIRMWARE-BISECTION-HELPER-CONVERGENCE-600S-20260902/`
