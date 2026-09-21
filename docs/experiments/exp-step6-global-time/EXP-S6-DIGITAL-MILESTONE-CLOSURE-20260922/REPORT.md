# EXP-S6-DIGITAL-MILESTONE-CLOSURE-20260922

## Formal result

```text
RESULT = PASS_STEP6_DIGITAL_MILESTONE_CLOSURE
VERDICT = PASS
AUDIT_GAP_COUNT = 0
AUDIT_CONTRADICTION_COUNT = 0

STEP6_DIGITAL_GLOBAL_TIME = PASS
STEP6_DIGITAL_SAME_PPS_CONSISTENCY = PASS
STEP6B_POSTFIT_TIMING = PASS
STEP6B_FIRST_SCHEDULED_TRIGGER = PASS
STEP6B_REARM_REPEATABILITY = PASS
STEP6_DIGITAL_MILESTONE = PASS

STEP6_PHYSICAL_PPS_BASELINE = NOT_EVALUATED
STEP6B_PHYSICAL_SCHEDULED_TRIGGER_EDGE = NOT_EVALUATED
```

This is the formal closure of the digital Step6 milestone.  It is based on an
offline audit of the existing raw records and does not claim a physical SMA
edge measurement.

## Execution and provenance

```text
BRANCH = exp/step6-Global-Time-Testing
LAPTOP/Pain_AUDIT_COMMIT = cee492a4
AUDITOR = scripts/analysis/step6_digital_milestone_closure.py
PAIN_HARDWARE_ACCESS = NO
```

The audit was executed on Pain after pulling the exact branch commit.  The
timing raw path reports were included explicitly because they are ignored by
the repository's general `*.rpt` rule; this makes the evidence set identical
on Laptop and Pain.

## Hardware contract

No new hardware action was performed in this closure experiment:

```text
COMPILE / FIRMWARE_BUILD = NO
FPGA_PROGRAM = NO
PTP_RESTART = NO
CPU/WR/PHY_RESET = NO
POWER_CYCLE = NO
TARGET_WRITE / ARM_WRITE = NO
SMA/FIBER/QSFP_CHANGE = NO
SI5340/MDIO_CHANGE = NO
FITTED_DESIGN_CHANGE = NO
```

## Audited evidence chain

### Step6A-1: Global-Time validity and late stability

The active-extension late-tail raw capture contains 61 paired tail samples,
61/61 valid samples, a 61-sample valid streak, 45 snapshot increments and 45
common TAI labels.  The raw record reports zero coherence violations and zero
digital cycle-label delta.  Slave readiness remained `SPLL_SEQ_STATE=8`,
`PSTAT_LOCKED=1`, `MAIN_LOCKED=1`, `PTP_STATE=9`, `PD_STATE=3`, and
`EXT_STATE=1` for the tail.  Reset signatures remained unchanged.

The earlier initial observability run is retained as a historical boundary:
its Slave `STATUS_TIME_VALID` was not valid.  It is not used as a PASS input;
the later active-extension tail is the requalification evidence.

### Step6A-2: same-PPS digital consistency

The same-PPS raw capture independently records five distinct common
`SNAPSHOT_TAI` labels.  Every common label has equal Master/Slave
`SNAPSHOT_CYCLES`, with:

```text
COMMON_TAI_LABELS = 5
EXACT_MATCH_COUNT = 5
MAX_ABS_DELTA_TICKS = 0
MAX_ABS_DELTA_NS = 0
COHERENCE_VIOLATION = 0
```

### Step6B post-fit scheduler timing

Both Master and Slave timing summaries contain all nine required scheduler
groups, each with setup and hold evidence.  Therefore all 36 required
board/group/type combinations have non-empty paths and non-negative slack.
The raw `.rpt` files are preserved in the timing experiment directory.

### Step6B first scheduled trigger

The first live-session raw record shows one target write per board and one ARM
write per board.  Both boards fired exactly once at:

```text
TARGET_TAI = 3433
TARGET_CYCLES = 62500000
MASTER_ACTUAL = (3433, 62500000)
SLAVE_ACTUAL  = (3433, 62500000)
DIGITAL_TRIGGER_DELTA_TICKS = 0
DIGITAL_TRIGGER_DELTA_NS = 0
```

### Step6B clean re-arm repeatability

The second raw record contains exactly six approved writes in order:

```text
Master ARM 1 -> 0
Slave  ARM 1 -> 0
Master TARGET_TAI := 6791
Slave  TARGET_TAI := 6791
Master ARM 0 -> 1
Slave  ARM 0 -> 1
```

The second trigger raised both fire counts from 1 to 2 and again produced:

```text
MASTER_ACTUAL = (6791, 62500000)
SLAVE_ACTUAL  = (6791, 62500000)
SECOND_TRIGGER_DELTA_TICKS = 0
SECOND_TRIGGER_DELTA_NS = 0
POST_FIRE_SAMPLES = 3
```

## Interpretation boundary

The digital `0 ns` value means that both boards captured the same 125 MHz
Global-Time timestamp label (one label tick is 8 ns).  It does **not** mean
that physical output-edge skew is zero, and it does not prove sub-nanosecond
physical synchronization.  Those two physical measurements remain
`NOT_EVALUATED` until an oscilloscope, scope CSV, or equivalent waveform
evidence is available.

The machine-readable audit result and per-check audit log are stored in this
directory as `analysis/summary.json` and `analysis/audit.txt`.
