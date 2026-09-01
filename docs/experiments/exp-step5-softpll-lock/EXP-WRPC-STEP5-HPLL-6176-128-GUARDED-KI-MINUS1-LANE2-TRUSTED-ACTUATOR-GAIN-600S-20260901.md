# EXP-WRPC-STEP5-HPLL-6176-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-GAIN-600S-20260901

## Purpose

Test the branch5-specified actuator-mapping change from 64 to 128
code-per-physical-step. The purpose is to determine whether reducing the
effective physical actuator aggressiveness lets the Helper loop remain inside
the lock band.

This experiment changes only the normal HPLL tracker mapping. Bootstrap,
PI parameters, lane, PHY/PTP setup, and the diagnostic transport remain
unchanged.

## Configuration

```text
branch       = exp/step5-softpll-lock
source HEAD  = 97d3446
board        = DE5 [1-11.2]
lane         = QSFPA lane 2
bootstrap    = 6176
code_step    = 128
kp           = -150
ki           = -1
shift        = 12
bias         = 5
y_min        = 5
y_max        = 65531
threshold    = 200
lock_samples = 10000
samples      = 600
sample_gap   = 1000 ms
window       = 599 s
transport    = trusted preload-then-toggle-commit
snapshot     = one atomic frozen snapshot per sample
```

The Slave JTAG image was rebuilt from `97d3446` with:

```text
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 128
```

Quartus compilation and programming both succeeded. Build timing remains
the known implementation caveat (`TIMING_CLOSED=NO`; worst setup slack
`-0.323 ns`).

## Preflight

After programming the new Slave image and waiting for startup, the trusted
runtime preflight passed:

```text
Master Step1  = PASS
Master Step2  = PASS
Master Step4A = PASS
Slave  Step1  = PASS
Slave  Step2  = PASS
Slave  Step3  = PASS
Slave  Step4B = PASS
WB_TRANSPORT_PROTOCOL                 = PRELOAD_THEN_TOGGLE_COMMIT
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH               = TRUSTED
RXERR delta                            = 0
reset deltas                           = 0
SPLL init stability                    = PASS
```

Preflight raw output:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-GAIN-600S-20260901-PREFLIGHT.log
```

## Long-run result

The complete 600-sample run finished successfully. The remote Quartus/Tcl
process reported success after 00:16:59.

```text
SAMPLES                         = 600
VALID_FRAMES                   = 600
INVALID_FRAMES                 = 0
WINDOW_SECONDS                 = 599.000
PI_TRACE_FRACTION              = 100.000%
PI_SNAPSHOT_REJECTS            = 0
PI_ACCOUNTING_FAILS            = 0
PI_OUTPUT_MISMATCH_FAILS       = 0
ANTI_WINDUP_VIOLATIONS         = 0
POSITION_CONTEXT_FAILS         = 0
MEASUREMENT_COHERENCE           = PASS
POSITION_ACCOUNTING             = PASS
TRANSACTION_ACCOUNTING          = PASS
```

Trusted transport remained clean for the entire window:

```text
SNAPSHOT_REQ_COUNT              = 600
SNAPSHOT_BANK_COMMIT_COUNT      = 600
SNAPSHOT_ACK_COUNT              = 600
SNAPSHOT_OVERWRITE_COUNT        = 0
ACK_TIMEOUT                     = 0
ACK_MISMATCH                    = 0
EPOCH_GENERATION_MISMATCH       = 0
EPOCH_CHANGED_DURING_READ      = 0
RXERR delta                     = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3    = PASS
```

## Actuator and lock evidence

```text
HELPER_ERROR_MEAN               = 127746.1191667
HELPER_ERROR_RMS                = 138430.779428
HELPER_ERROR_MAX_ABS            = 150000
FRACTION_ABS_ERROR_LE_200       = 1.0
LOW_RAIL_SAMPLES                = 511 (85.167%)
HIGH_RAIL_SAMPLES               = 0   (0.000%)
NO_RAIL_SAMPLES                 = 89  (14.833%)
ERROR_BAND_EXIT_EVENTS          = 6
FREQ_ERROR_ZERO_CROSSINGS       = 24
RAIL_TO_RAIL_CYCLE_COMPLETE     = 0
```

The mapping change created some interior samples and a small amount of
lock-band occupancy, but the Helper lock counter never accumulated:

```text
HELPER_LOCK_COUNT_MAX            = 0
HELPER_LOCK_COUNT_FINAL          = 0
HELPER_LOCKED_EVER               = 0
HELPER_LOCKED_FINAL              = 0
MAIN_ENABLED_EVER                = 0
MAIN_FREQ_LOCKED_EVER            = 0
MAIN_PHASE_LOCKED_EVER           = 0
MAIN_LOCKED_EVER                 = 0
PSTAT_LOCKED_EVER                = 0
PSTAT_LOCKED_FINAL               = 0
```

The run remained stable from a reset and initialization perspective:

```text
SPLL_INIT_COUNT first/final      = 1 / 1
SPLL_DELOCK_COUNT first/final    = 0 / 0
SPLL_INIT_DELTA                  = 0
SPLL_DELOCK_COUNT_DELTA          = 0
BOOT_GENERATION delta            = 0
CPU reset delta                  = 0
WR-core reset delta              = 0
SI_CONFIG drop delta             = 0
RESET_STABLE                     = PASS
```

## Interpretation

Relative to the `code_step=64` baseline (`NO_RAIL_FRACTION=0%`,
`HELPER_LOCK_COUNT_MAX=0`), `code_step=128` did produce non-rail samples and
some `|error| <= 200` samples. However, the three branch5 acceptance
conditions must all hold:

```text
NO_RAIL_FRACTION > 0       = YES (14.833%)
FRACTION_ABS_ERROR_LE_200 > 0 = YES (1.0)
HELPER_LOCK_COUNT_MAX > 0  = NO (0)
```

Therefore the actuator-gain reduction direction is not effective for
achieving Helper lock. This is not Step5 completion evidence. The observer
was in single-snapshot mode; its A/B-labelled compatibility counters are not
treated as a double-read experiment.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                   = YES
STEP4B_REVALIDATED                = YES
ACTUATOR_GAIN_REDUCTION_EFFECTIVE = NO
STEP5_COMPLETE                    = NO
MERGE_APPROVED                    = NO
```

The complete raw run is retained on the remote host at:

```text
remote: docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-128-GUARDED-KI-MINUS1-LANE2-TRUSTED-ACTUATOR-GAIN-600S-20260901.log
```
