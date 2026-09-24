# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-MAIN-TRACE-2S-PUBLICATION-MAIN-FREQUENCY-PRELOCK-OBSERVABILITY-600S-20260902

## Purpose

This run follows the branch5 handoff after `9e638f2`. Step4B is already settled and revalidated, while Step5 remains incomplete because the Main frequency-lock boundary has not been reached. The purpose of this run is to obtain trustworthy Main frequency/PI telemetry while checking whether the Helper lock gate remains reachable.

## Baseline and controlled change

- Experiment branch: `exp/step5-softpll-lock`
- Baseline firmware source: `88604a5ca174fd3b36b0a8eb435ec1773dd061a3`
- Baseline branch evidence: `9e638f228c18b6382f6ab311e41aee31cf3e4874`
- Frozen fitted database: the existing fitted `quartus/jtag_runtime_diag` project
- Firmware patch applied to the baseline: only the `7585a0619373c84a58431920a0985587c1b30cad` Main trace publication-cadence change
- Controlled firmware variable: Main read-only diagnostic trace publication cadence, from each normal diagnostics tick to approximately every 20 ticks (about 2 seconds)
- Measurement-only change: the observer counts each coherent `(epoch, update_count)` pair once, so repeated reads of one slow publication do not distort frequency/PI distributions

The firmware/controller behavior, SoftPLL cadence, and lock parameters remain unchanged. No synthesis, fitter, place-and-route, or timing implementation is allowed in this run; only MIF generation and assembler/update-MIF operations are allowed against the frozen fit.

## Fixed controller configuration

```text
bootstrap = 6208
code_per_physical_step = 16
helper kp = -300
helper ki = -1
shift = 12
bias = 5
helper threshold = 200
helper lock_samples = 10000
QSFPA lane = 2
normal tracker = ON
```

## Required procedure

1. Build Master and Slave MIFs from the `88604a5` baseline plus only the Main trace publication patch.
2. Update MIFs and assemble SOFs using the existing fitted project; verify fit and STA reports are byte-identical to the frozen baseline.
3. Program Slave first, then Master.
4. Require three consecutive settled preflight passes:

```text
Master Step1/2/4A = PASS
Slave Step1/2/3/4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
RXERR delta = 0
all reset deltas = 0
```

5. If and only if the preflight gate passes, run:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 6000 100 "DE5 [1-11.2]"
```

The 600-second observer must report coherent-frame counts, deduplicated Main frequency error/PI statistics, Helper lock evidence, Main frequency/phase/full lock evidence, PSTAT, SPLL delock delta, RXERR delta, and reset deltas.

## Required interpretation

This run is not Step5 PASS merely because telemetry is readable. Step5 requires the complete lock chain and the defined stable-lock window. The key observations are:

```text
Helper lock remains reachable or falls back
Main frequency error distribution while Main is enabled
MAIN_FREQ_LOCK_COUNT_MAX and MAIN_FREQ_LOCKED_EVER
MAIN_PHASE_LOCKED_EVER and MAIN_LOCKED_EVER
PSTAT_LOCKED_EVER
SPLL_DELOCK_COUNT_DELTA = 0
all reset deltas = 0
normal transaction accounting = PASS
```

## Results

### Frozen-fit build and programming

The exact `88604a5` source was used in a detached worktree and only the
`7585a06` `vendor/wrpc-sw/lib/task-diags.c` publication-cadence patch was
applied. Master and Slave MIFs were built successfully. The existing fitted
project was copied to a separate staging tree and processed with MIF update
plus assembler only.

```text
SOURCE_COMMIT = 88604a5ca174fd3b36b0a8eb435ec1773dd061a3
PATCH_COMMIT  = 7585a0619373c84a58431920a0985587c1b30cad
FIT_STA_BEFORE_AFTER = IDENTICAL

MASTER_MIF_SHA256 = 54dac7f8559c085243b26477a2d5a35a3501497fabb8643d927f5357bcf4d58a
SLAVE_MIF_SHA256  = 8caeab7790f6ccd32df4e81a2d3cd0da22ff5b1939ba7ed6cfefdc2d4a8cf3d6
MASTER_SOF_SHA256 = 23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d
SLAVE_SOF_SHA256  = 04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc
```

Slave `DE5 [1-11.2]` and Master `DE5 [1-11.1]` programming both completed
successfully with zero errors and zero warnings.

### Three settled preflight results

All three valid post-program captures passed the upstream gate:

```text
                         preflight-1  preflight-2  preflight-3
Master Step1/2/4A             PASS         PASS         PASS
Slave Step1/2/3/4B           PASS         PASS         PASS
STEP4B_ALLOWED                YES          YES          YES
STEP4B_RESULT                 PASS         PASS         PASS
STEP4B_FIRST_INACTIVE         ACTIVE       ACTIVE       ACTIVE
JTAG_WB_DIAGNOSTIC_PATH       TRUSTED      TRUSTED      TRUSTED
PRELOAD_PROTOCOL_REVALIDATION PASS         PASS         PASS
RXERR delta                   0            0            0
CPU/WR-core reset delta       0            0            0
```

The first attempted preflight was a path-invocation error because the reader
was called from the home directory; it produced no hardware result and was
not counted. The three captures above were rerun from the repository after
programming and are the valid preflight set.

### 600-second Main-frequency prelock result

The read-only observer completed the full 6000-sample window on Slave
`DE5 [1-11.2]`:

```text
SAMPLES                       = 6000
ELAPSED                       = 1090.287 s
TRACE_VALID                   = 6000
TRACE_UNIQUE                  = 575
TRACE_DEDUP_SKIPPED           = 5425
FRAME_VALID                   = 5729
INVALID                       = 0

MAIN_ENABLED_FRACTION         = 1.0
MAIN_FREQ_ERROR_MEAN          = -1036.72869565
MAIN_FREQ_ERROR_RMS           = 1067.25506914
MAIN_FREQ_ERROR_MIN/MAX       = -1270 / -725
MAIN_FREQ_ERROR_MAX_ABS       = 1270
FRACTION_ABS_FREQ_ERROR_LE_50 = 0.0

MAIN_FREQ_LOCK_COUNT_MAX      = 0
MAIN_FREQ_LOCKED_EVER         = 0
MAIN_PHASE_LOCKED_EVER        = 0
MAIN_LOCKED_EVER              = 0
PSTAT_LOCKED_EVER              = 0

MAIN_PI_LOW_RAIL_FRACTION     = 1.0
MAIN_PI_HIGH_RAIL_FRACTION    = 0.0
MAIN_PI_NO_RAIL_FRACTION      = 0.0

HELPER_LOCK_COUNT_MAX         = 10000
HELPER_LOCKED_EVER            = 1
HELPER_LOCKED_FRACTION        = 0.459
HELPER_LOCKED_FINAL            = 0

SPLL_DELOCK_COUNT_DELTA       = 0
RXERR_DELTA                   = 0  (post-observer health snapshot)
RESET_STABLE                  = PASS
BOOT_GENERATION_FIRST/FINAL   = 1 / 1
TELEMETRY_RESULT              = PASS
```

The Main trace is internally consistent (`PRELOCK_ERROR_MISMATCHES=0` and
`MEASUREMENT_FAILS=0`), but its deduplicated frequency error never enters the
required +/-50 band and its PI output remains on the low rail. Thus the first
inactive Step5 boundary is Main frequency lock. Helper lock was reached
intermittently, but was not stable at the end of the window.

The post-observer read-only health snapshot retained `STEP4B_ALLOWED=YES`,
`STEP4B_RESULT=PASS`, trusted JTAG/WB transport, zero RXERR delta, and zero
CPU/WR-core reset deltas.

## Formal handoff

```text
STEP4B_COMPLETE           = YES
STEP4B_REVALIDATED        = YES FOR 88604A5 + 7585A06 IMAGE
HELPER_LOCK_GATE_CROSSED  = YES
HELPER_LOCK_STABLE        = NO
STEP5_FIRST_INACTIVE      = MAIN_FREQUENCY_LOCK
STEP5_COMPLETE             = NO
MERGE_APPROVED             = NO
```

## Raw evidence

All build, MIF-only assembly, programming, preflight, Main observer, derived
fraction, and post-observer health logs are stored under:

`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-MAIN-TRACE-2S-PUBLICATION-MAIN-FREQUENCY-PRELOCK-OBSERVABILITY-600S-20260902/`
