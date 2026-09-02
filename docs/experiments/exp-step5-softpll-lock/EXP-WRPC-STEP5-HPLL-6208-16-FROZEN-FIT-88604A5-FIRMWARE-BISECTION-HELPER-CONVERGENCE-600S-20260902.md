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
RUN_RESULT                = COMPLETED_HELPER_PROGRESS_NO_STEP5
```

## Frozen-fit build and programming result

The exact `88604a5` firmware source revision was used in a detached worktree.
Master and Slave MIFs were built successfully, then applied to a copy of the
same fitted database with MIF update plus assembler only. The cdb logs show
both `wrc.mif` files as processed; no synthesis, fitter, or place-and-route
was run.

```text
SOURCE_COMMIT = 88604a5ca174fd3b36b0a8eb435ec1773dd061a3
MASTER_MIF_SHA256 = 63f55795f9d8a8bdef1ea266a026c6ed89f72e9e72ff6b95f28c2d05daa63cf9
SLAVE_MIF_SHA256  = ce485d0b0073367dab8195eeea7afeab794540dd721c2fa2e6b4458712b007a5
MASTER_SOF_SHA256 = 865004af63048ba0625e266274f9aeb44615ef668d5bfdae080b2f0e25690906
SLAVE_SOF_SHA256  = a73b9b78385f82bc6a5e69b4ebe7a76372cbe21360597f25d6d4481c2c6db79a
FIT_STA_BEFORE_AFTER = IDENTICAL
```

Slave `DE5 [1-11.2]` and Master `DE5 [1-11.1]` programming both completed
successfully with zero errors and zero warnings.

## Three settled preflight results

All three post-program settled captures passed the upstream gate:

```text
                         preflight-1  preflight-2  preflight-3
Master Step1/2/4A             PASS         PASS         PASS
Slave Step1/2/3/4B           PASS         PASS         PASS
STEP4B_ALLOWED                YES          YES          YES
STEP4B_RESULT                 PASS         PASS         PASS
STEP4B_FIRST_INACTIVE         ACTIVE       ACTIVE       ACTIVE
JTAG_WB_DIAGNOSTIC_PATH       TRUSTED      TRUSTED      TRUSTED
PRELOAD_PROTOCOL_REVALIDATION PASS         PASS         PASS
DMTD_REF_DECREASE_COUNT       0            0            0
DMTD_FB_DECREASE_COUNT        0            0            0
RXERR_DELTA                   0            0            0
reset deltas                  0            0            0
```

## 600-second Helper convergence result

The read-only observer completed normally on Slave `DE5 [1-11.2]`:

```text
SAMPLES                       = 6000
VALID_FRAMES                  = 5382
INVALID_FRAMES                = 618
WINDOW_SECONDS                = 599.901
HELPER_LOCK_COUNT_MAX         = 10000
HELPER_LOCK_COUNT_FINAL       = 0
HELPER_LOCKED_SEEN            = 1260
HELPER_LOCKED_FINAL           = 0
FIRST_HELPER_LOCK_SAMPLE      = 64
HELPER_ERROR_MEAN             = 25750.5870212
HELPER_ERROR_RMS              = 62122.4870057
HELPER_ERROR_MAX_ABS          = 150000
HELPER_ERROR_FRACTION_LE_200  = 82.1866865006
HELPER_OUTPUT_RAIL5_FRACTION  = 17.1869193608
MAIN_ENABLED_FINAL            = 1
MAIN_FREQ_LOCKED_FINAL        = 0
MAIN_PHASE_LOCKED_FINAL       = 0
MAIN_LOCKED_FINAL             = 0
PSTAT_LOCKED_FINAL            = 0
SPLL_DELOCK_COUNT_DELTA       = 0
NORMAL_REQ_DELTA              = 5551
NORMAL_COMPLETED_DELTA        = 5551
DCO_STEP_DELTA                = 5553
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_BOOT_GENERATION_DELTA  = 0
RESET_CPU_DELTA               = 0
RESET_WR_CORE_DELTA           = 0
RESET_SI_CONFIG_DELTA         = 0
```

The `88604a5` revision therefore restores intermittent Helper lock progress
relative to `004f439`, and it reaches `MAIN_ENABLED=1`, but it does not hold
Helper lock through the window and does not enter Main frequency lock. The
invalid-frame population is retained in the report; no invalid sample is used
to claim lock.

## Final judgement

```text
STEP4B_COMPLETE           = YES
STEP4B_REVALIDATED        = YES FOR 88604A5 IMAGE
HELPER_LOCK_GATE_CROSSED  = YES
HELPER_LOCK_STABLE        = NO
STEP5_FIRST_INACTIVE      = MAIN_FREQUENCY_LOCK
STEP5_COMPLETE            = NO
MERGE_APPROVED            = NO
```

This is not merge evidence. The next firmware-changing boundary remains
subject to branch5 review of this committed result.

## Raw evidence

The build, MIF-only assembly, programming, preflight, and Helper observer logs
will be stored under:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-FIRMWARE-BISECTION-HELPER-CONVERGENCE-600S-20260902/`
