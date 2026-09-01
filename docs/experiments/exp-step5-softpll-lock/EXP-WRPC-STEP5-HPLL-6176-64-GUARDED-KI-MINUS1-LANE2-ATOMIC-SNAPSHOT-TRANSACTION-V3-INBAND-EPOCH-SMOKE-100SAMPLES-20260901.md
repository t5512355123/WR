# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-ATOMIC-SNAPSHOT-TRANSACTION-V3-INBAND-EPOCH-SMOKE-100SAMPLES-20260901

## Formal status

```text
SOURCE_FUNCTIONAL_COMMIT = 493b54b757cb0473e1c0e070f6db3ee7ad9852fa
DOCUMENTATION_HEAD = b5d786eb1fa5c7071704a46860357b2482ea5f3b
BOARD = DE5 [1-11.2]
LANE = QSFPA lane 2
BOOTSTRAP = 6176
CODE_PER_PHYSICAL_STEP = 64
KP = -150
KI = -1
THRESHOLD = 200
LOCK_SAMPLES = 10000
READ_ONLY = 1
V3_ATOMIC_SNAPSHOT_SMOKE = FAIL
EXPERIMENT_VALID_FOR_LONG_STEP5_OBSERVATION = NO
KI_REDUCTION_DIRECTION_EFFECTIVE = NOT_ADJUDICATED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Purpose

Validate the V3 in-band PI snapshot transport before using the observer for the 1800-second Step5 closed-loop experiment. The V3 transport was intended to bind each frozen PI payload to the request through the in-band epoch, without relying on the V2 `BANK_SEQ` overlay metadata.

No source, PI control parameter, lane, bootstrap, DMTD, tracker, DCO, sequencer, or reset-tree change was made for this smoke run.

## Procedure

The authorized read-only observer was run on pain:

```text
/mnt/ds1515/opt/intelFPGA_pro/21.3/quartus/bin/quartus_stp -t \\
scripts/jtag/read_step5_helper_pi_state_rail_audit.tcl \\
100 100 "DE5 [1-11.2]"
```

The run used 100 samples with a 100 ms gap. The preceding role/image provenance audit had already confirmed the correct Master/Slave images, clean QSFPA lane-2 preflight, `PTP=SLAVE` on the target, `RXERR delta=0`, and stable reset deltas.

## V3 result

```text
SAMPLES = 100
VALID_FRAMES = 67
INVALID_FRAMES = 33
PI_TRACE_PRESENT = 67
PI_SNAPSHOT_REJECTS = 33

ACK_TIMEOUT = 4
ACK_MISMATCH = 2
EPOCH_GENERATION_MISMATCH = 2
EPOCH_CHANGED_DURING_READ = 2

MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
TRANSACTION_ACCOUNTING = PASS
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
POSITION_CONTEXT_FAILS = 0

ATOMIC_SNAPSHOT_TRANSPORT_V3 = FAIL
```

The V3 pass gate required at least 99 valid frames, at most 1 invalid frame, and zero transport/epoch errors. The observed `67/100` valid frames and nonzero timeout, mismatch, and epoch counters fail that gate decisively.

## Runtime observations

```text
SPLL_INIT_COUNT delta = 0
SPLL_DELOCK_COUNT delta = 0
CLEAR_DACS delta = 0
BOOT reset delta = 0
CPU reset delta = 0
WR-core reset delta = 0
SI reset delta = 0

HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCK_COUNT_FINAL = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
```

Among accepted frames, the measured helper error remained at the low output rail:

```text
HELPER_ERROR_MEAN = 150000
HELPER_ERROR_MAX_ABS = 150000
LOW_RAIL_SATURATION = CONFIRMED
FREQ_ZERO_CROSSINGS = 0
```

This is useful diagnostic evidence, but because the V3 observer itself failed its transport validity gate, it cannot be used to conclude whether `KI=-1` improves or worsens closed-loop convergence.

## Decision

The run is not a valid Step5 dynamics experiment. Per the branch5 gate, stop immediately:

```text
V3_ATOMIC_SNAPSHOT_SMOKE = FAIL
EXPERIMENT_VALID_FOR_LONG_STEP5_OBSERVATION = NO
KI_REDUCTION_DIRECTION_EFFECTIVE = NOT_ADJUDICATED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

Do not run the 1800-second observer, do not change `ki`, `kp`, or bootstrap based on this run, and do not merge to `main`. The next action is to send this failure report to branch5 and request the next diagnostic-only direction.
