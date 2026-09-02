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

Pending hardware execution.

## Formal handoff

```text
STEP4B_COMPLETE = YES
STEP4B_REVALIDATED = YES
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```
