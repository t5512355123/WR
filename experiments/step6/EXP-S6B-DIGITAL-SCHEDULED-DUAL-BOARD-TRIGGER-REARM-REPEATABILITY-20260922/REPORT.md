# EXP-S6B-DIGITAL-SCHEDULED-DUAL-BOARD-TRIGGER-REARM-REPEATABILITY-20260922

## Verdict

```text
RESULT = PASS_DIGITAL_SCHEDULED_DUAL_BOARD_TRIGGER_REARM_REPEATABILITY
VERDICT = PASS
STEP6A = PASS
STEP6B_1_DIGITAL_SCHEDULED_TRIGGER = PASS
STEP6_PHYSICAL_PPS_BASELINE = NOT_EVALUATED
STEP6B_PHYSICAL_SCHEDULED_TRIGGER_EDGE = NOT_EVALUATED
```

This result proves a second digital scheduled trigger at the same Global-Time
label in the same live session. It does not claim physical SMA edge skew.

## Provenance and execution

```text
BRANCH = exp/step6-Global-Time-Testing
LAPTOP_COMMIT = 9bb379fc
PAIN_COMMIT = 9bb379fc
PAIN_WORKTREE = /home/b10504072/04_WR/pain-worktrees/step6-global-time
```

The observer and offline checks were added on Laptop, pushed to GitHub, pulled
to Pain, and verified there. Quartus STP parse-only harness passed before the
live run.

## Hardware contract

The already-programmed and already-fired Step6B session was reused. There was
no compile, firmware build, FPGA programming, PTP restart, CPU/WR/PHY reset,
power cycle, fiber/QSFP change, SI5340/MDIO write, or SMA change.

```text
MASTER_PROGRAM_COUNT = 0
SLAVE_PROGRAM_COUNT = 0
```

The only functional writes were the six approved source writes, each exactly
once and in the required order:

```text
1. Master ARM 1 -> 0
2. Slave  ARM 1 -> 0
3. Master TARGET_TAI := 6791
4. Slave  TARGET_TAI := 6791
5. Master ARM 0 -> 1
6. Slave  ARM 0 -> 1
```

## Observed gates

Before the first write:

```text
PRE_GATE_PAIRS = 3
PRE_COMMON_TAI_COUNT = 2
COHERENCE_VIOLATION = 0
INITIAL_RESULT = PASS
```

The post-fire scheduler state was the expected prior result: target TAI
`3433`, ARM source/sync asserted, armed cleared, fired asserted, and
fire-count `1` on both boards.

After de-arm:

```text
DEARM_RESULT = PASS
POST_DEARM_GATE_PAIRS = 3
POST_DEARM_COMMON_TAI_COUNT = 2
POST_DEARM_GATE_RESULT = PASS
```

The new target was selected from `T0=6771`:

```text
NEW_TARGET_TAI = 6791
TARGET_CYCLES = 62500000
TARGET_RESULT = PASS
ARM_RESULT = PASS
```

## Second scheduled trigger

```text
CAPTURE_SAMPLES = 27
POST_FIRE_SAMPLES = 3

MASTER_FIRE_COUNT = 2
SLAVE_FIRE_COUNT = 2

MASTER_ACTUAL = (TAI=6791, CYCLES=62500000)
SLAVE_ACTUAL  = (TAI=6791, CYCLES=62500000)

SECOND_TRIGGER_DELTA_TICKS = 0
SECOND_TRIGGER_DELTA_NS = 0
```

The raw stop record confirms each ARM0, target, and ARM1 write occurred once;
no retry or extra write was issued. Quartus STP completed with zero errors and
zero warnings.

## Reproducibility artifacts

- `PLAN.md`
- `raw/observe/observe.log`
- `raw/protocol.txt`
- `raw/stop.txt`
- `analysis/summary.json`
- `analysis/analyzer.txt`

## Scope limitation

The physical PPS/SMA measurement remains pending because no oscilloscope or
waveform export was available in this environment. Therefore the physical
PPS baseline and physical scheduled-trigger edge remain `NOT_EVALUATED`.
