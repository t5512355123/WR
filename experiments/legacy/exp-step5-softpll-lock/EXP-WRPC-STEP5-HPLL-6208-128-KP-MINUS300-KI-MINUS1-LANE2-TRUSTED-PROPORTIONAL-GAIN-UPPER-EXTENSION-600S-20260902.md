# EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902

## Purpose

Run the branch5-directed proportional-gain upper-extension experiment at the
established operating point. The only intended control change from the prior
`kp=-225, ki=-1` run was:

```text
kp: -225 -> -300
```

The corrected signed-32-bit raw-error observer from `db627a2` was retained.

## Configuration and provenance

```text
branch             = exp/step5-softpll-lock
build/source HEAD  = c93c096
control change     = c93c096
observer baseline  = db627a2
board              = DE5 [1-11.2]
lane               = QSFPA lane 2
bootstrap          = 6208
code_step          = 128
kp                 = -300
ki                 = -1
shift              = 12
bias               = 5
y_min              = 5
y_max              = 65531
threshold          = 200
lock_samples       = 10000
samples            = 600
sample_gap         = 1000 ms
window             = 599 s
transport          = trusted preload-then-toggle-commit
snapshot           = one atomic frozen snapshot per sample
quartus_stp        = Intel Quartus Prime 17.0
```

The only firmware control change was `kp=-225 -> -300`; bootstrap, code step,
ki, PI limits, lane, and runtime procedure were held fixed. Both JTAG images
were freshly built and programmed onto Slave first, then Master:

```text
Master SOF SHA256 = 66683c1f90973c2519cb45d80bd0033ce9998104ccd7866da26d6f9c63b9f335
Slave  SOF SHA256 = 5ebc85a275ed58269ccc882d591033f9072531deb22d35aaa94cd9ec741cabc7
FITTER_STATUS     = Successful
TIMING_CLOSED     = NO
```

`TIMING_CLOSED=NO` remains an implementation caveat and is not being treated
as a functional Step5 result.

## Trusted preflight gate

The first four post-program read-only preflights observed the familiar
startup/recovery transient: Slave `WDIAGS_PTP` was still transitioning and
`core_tm_link_up/core_link_ok` were reported as `0/1`. Those captures were not
used to start the long run. The same image pair was re-programmed once more in
the same Slave-to-Master order, then the settled trusted retry passed:

```text
Master Step1/Step2/Step4A       = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP1_REGRESSION                = PASS
STEP2_REGRESSION                = PASS
STEP3_REGRESSION                = PASS
STEP4B_ALLOWED                  = YES
STEP4B_RESULT                   = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY  = ACTIVE
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
DMTD_REF_DECREASE_COUNT        = 0
DMTD_FB_DECREASE_COUNT         = 0
WDIAGS_RXERR delta              = 0
```

The final retry showed positive DMTD/TAG/TRR/IRQ/helper activity and no reset
or RXERR delta. Only this settled retry was used as the Step5 preflight gate.

## Trusted 600-second result

The run completed with valid, coherent atomic snapshots:

```text
SAMPLES                         = 600
VALID_FRAMES                   = 600
INVALID_FRAMES                 = 0
WINDOW_SECONDS                 = 599.000
PI_TRACE_PRESENT               = 600
PI_TRACE_FRACTION              = 100.000%
PI_SNAPSHOT_REJECTS            = 0
PI_ACCOUNTING_FAILS            = 0
PI_OUTPUT_MISMATCH_FAILS       = 0
ANTI_WINDUP_VIOLATIONS         = 0
POSITION_CONTEXT_FAILS         = 0
MEASUREMENT_COHERENCE          = PASS
POSITION_ACCOUNTING            = PASS
TRANSACTION_ACCOUNTING         = PASS
```

The controller dynamics were:

```text
HELPER_ERROR_SAMPLES           = 600
HELPER_ERROR_MEAN              = 67988.7226667
HELPER_ERROR_RMS               = 100998.451818
HELPER_ERROR_MAX_ABS           = 150000
FRACTION_ABS_ERROR_LE_200      = 8.0%
RAW_ERROR_MEAN                 = 186750473.872
RAW_ERROR_MIN                  = -3581
RAW_ERROR_MAX                  = 822184383
RAW_ERROR_POSITIVE_FRACTION    = 71.6666666667%
UNCLAMPED_BELOW_MIN_SAMPLES    = 272
LOW_RAIL_SAMPLES               = 272 (45.333%)
HIGH_RAIL_SAMPLES              = 0 (0.000%)
NO_RAIL_FRACTION               = 54.667%
ERROR_BAND_EXIT_EVENTS         = 42
FREQ_ERROR_MEAN                = 217.528333333
FREQ_ERROR_RMS                 = 323.978458646
FREQ_ERROR_MAX_ABS             = 504
FREQ_ERROR_ZERO_CROSSINGS      = 81
RAIL_TO_RAIL_CYCLE_COMPLETE    = 0
DYNAMICS_CANDIDATE             = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
LOW_RAIL_SATURATION             = NO
ACTUATOR_RANGE_LIMIT_OR_REQUIRED_NEGATIVE_AUTHORITY = NOT_CONFIRMED
CAUSALITY_CASE                 = B
```

The run entered the interior/error band during the first part of the window,
then drifted to low rail. The final controller state was:

```text
TARGET_FINAL                   = 5
APPLIED_FINAL                  = 5
HELPER_ERROR_FINAL             = 150000
HELPER_OUTPUT_FINAL            = 5
PI_INTEGRATOR_BEFORE_FINAL     = 39185055
PI_I_NEW_FINAL                 = 39035055
PI_INTEGRATOR_AFTER_FINAL      = 39185055
PI_UNCLAMPED_FINAL             = -1451
PI_CLAMPED_FINAL               = 5
PI_CLAMP_SIDE_FINAL            = -1
```

## Lock and runtime stability

No Helper or main lock was observed:

```text
HELPER_LOCKED_EVER              = 0
HELPER_LOCKED_FINAL             = 0
HELPER_LOCK_COUNT_MAX           = 0
HELPER_LOCK_COUNT_FINAL         = 0
MAIN_ENABLED_EVER               = 0
MAIN_FREQ_LOCKED_EVER           = 0
MAIN_PHASE_LOCKED_EVER          = 0
MAIN_LOCKED_EVER                = 0
PSTAT_LOCKED_EVER               = 0
PSTAT_LOCKED_FINAL              = 0
```

The runtime remained alive without SoftPLL restart or receiver errors:

```text
SPLL_INIT_COUNT_FIRST/FINAL     = 1 / 1
SPLL_INIT_DELTA                 = 0
CLEAR_DACS_DELTA                = 0
SPLL_DELOCK_COUNT_FIRST/FINAL   = 0 / 0
BOOTSTRAP_COMPLETED_FINAL       = 6208
BOOTSTRAP_COMPLETED_DELTA       = 0
BOOTSTRAP_DONE_FINAL            = 1
BOOT_GENERATION_DELTA           = 0
CPU_RESET_DELTA                 = 0
WR_CORE_RESET_DELTA             = 0
SI_CONFIG_DROP_DELTA            = 0
RXERR_DELTA                     = 0
RESET_STABLE                    = PASS
```

## Trusted transport result

```text
SNAPSHOT_REQ_COUNT              = 600
SNAPSHOT_BANK_COMMIT_COUNT      = 600
SNAPSHOT_ACK_COUNT              = 600
SNAPSHOT_OVERWRITE_COUNT        = 0
SNAPSHOT_REQ_DELTA              = 599
SNAPSHOT_BANK_COMMIT_DELTA      = 599
SNAPSHOT_ACK_DELTA              = 599
ACK_TIMEOUT                     = 0
ACK_MISMATCH                    = 0
EPOCH_GENERATION_MISMATCH       = 0
EPOCH_CHANGED_DURING_READ      = 0
ATOMIC_SNAPSHOT_TRANSPORT_V3    = PASS
FROZEN_BANK_READ_STABILITY      = PASS
```

## Comparison with the prior proportional-gain bracket

```text
metric                         kp=-150         kp=-225         kp=-300
HELPER_ERROR_MEAN              76983.1867      74000.0885      67988.7227
HELPER_ERROR_RMS               107480.8868     105361.5173     100998.4518
NO_RAIL_FRACTION               48.667%         50.667%         54.667%
LOW_RAIL_FRACTION              51.333%         49.333%         45.333%
FRACTION_ABS_ERROR_LE_200      3.5%            4.667%          8.0%
FREQ_ERROR_ZERO_CROSSINGS      75              74              81
HELPER_LOCK_COUNT_MAX          0               0               0
```

`kp=-300` was effectively applied and improved the observed full-window
dynamics relative to `kp=-225`, but the improvement did not produce Helper,
Main, or PSTAT lock. It is therefore not Step5 completion.

## Milestone status pending branch5 review

```text
STEP4B_COMPLETE                         = YES
STEP4B_REVALIDATED                      = YES
PROPORTIONAL_GAIN_KP_MINUS300_EFFECTIVE = NO (no lock progress)
PROPORTIONAL_GAIN_KP_MINUS300_DIRECTION_IMPROVED = YES
STEP5_COMPLETE                          = NO (provisional, no lock observed)
MERGE_APPROVED                          = NO
```

The branch must not be merged until branch5 explicitly returns both
`STEP5_COMPLETE=YES` and `MERGE_APPROVED=YES`.

## Evidence

```text
initial transient preflight:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-PREFLIGHT.log

settled trusted retry preflight:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-PREFLIGHT-TRUSTED-RETRY5.log

trusted 600-second run:
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-128-KP-MINUS300-KI-MINUS1-LANE2-TRUSTED-PROPORTIONAL-GAIN-UPPER-EXTENSION-600S-20260902-RUN1.log
```
