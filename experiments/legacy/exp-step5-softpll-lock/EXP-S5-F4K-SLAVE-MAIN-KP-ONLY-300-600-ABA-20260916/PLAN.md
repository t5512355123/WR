# EXP-S5-F4K-SLAVE-MAIN-KP-ONLY-300-600-ABA-20260916

## Scope and approval

This is the approved F4K control-direction experiment. The user explicitly
approved the complete three-arm comparison and authorized the experiment
details without further confirmation.

The only functional variable is Slave Main proportional gain:

| Arm | Slave Main Kp | Slave Main Ki | Slave prelock boost |
|---|---:|---:|---:|
| A1 | 300 | 1 | 20 |
| B | 600 | 1 | 20 |
| A2 | 300 | 1 | 20 |

Master Main remains Kp=300, Ki=1, boost=20 in every arm. Helper remains
Kp=-2250, Ki=-2. The legacy multi-parameter candidate remains disabled.

The F4J producer snapshot and its schema remain unchanged. The observer only
adds arm/configuration metadata; it does not write control registers, request
a Helper PI snapshot, drain the debug FIFO, or start a second reader.

## Fixed boundaries

No other PI gain, threshold, lock/delock sample count, anti-windup setting,
branch condition, detector rule, DAC order/content, timeout/retry,
bootstrap, arbiter, mailbox, PHY, reset, RTL, SDB, or runtime command may
change. A 120-second arm cannot be reported as Step5 PASS; the result is only
a directionality diagnostic.

## Procedure

For each arm, in order:

1. Laptop source/config audit, offline tests, commit and push.
2. Pain exact pull of that commit; clean Master and Slave firmware/Quartus
   build; record ELF/BIN/MIF/SOF hashes and timing status.
3. Program Master on `DE5 [1-11.1]` and Slave on `DE5 [1-11.2]` using the
   existing JTAG scripts, then run a 10-second smoke and a 120-second formal
   F4J capture with hard limit 130 seconds.
4. Copy raw logs back to this experiment directory, replay them, and write the
   arm report and manifest.
5. Commit and push only this experiment's new evidence before proceeding to
   the next arm.

The comparison uses a common-length producer window. Primary evidence is
`Delta PHASE_IN_BAND / Delta PHASE_DETECTOR`; secondary evidence includes
phase-active ratio, handoff rate, frequency-error distribution, sampled phase
count/lock state, and Helper/PHY/WR/reset safety.

The pre-registered interpretation is:

- A1/A2 in-band ratio difference over 10 percentage points:
  `BASELINE_NOT_REPRODUCIBLE`.
- B at least 10 percentage points above both baselines, without the specified
  active-ratio, handoff, or safety regression:
  `KP_INCREASE_DIRECTION_SUPPORTED`.
- Otherwise, with valid arms:
  `KP_DOUBLING_NOT_SUPPORTED`.
- Any lock evidence in a 120-second arm is reported as
  `LOCK_OBSERVED_NOT_CLOSED`, never as Step5 PASS.

All classifications keep `STEP5_PASS=NO` and `MERGE_APPROVED=NO`.
