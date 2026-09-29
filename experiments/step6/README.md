# Step 6 — Global Time and Scheduled Trigger

**Current functional milestone: PASS for the pointwise dashboard-equivalent gate.**
The frozen Step 6 source/images were independently rebuilt and programmed;
historical evidence also confirms valid Global Time on both boards, five
matching common PPS labels, and two repeatable dual-board scheduled digital
triggers.

The latest read-only 300-second Slave capture explicitly checked the complete
dashboard Step 1 gate, valid/stable Global Time, all five Step 5 lock signals,
and strict `abs(CKO) < 60 ps`. Step 1, Global Time, and all five lock signals
were high in 958/958 rows. Two consecutive sampled rows (#91–92, 296 ms apart)
reported +59 ps, matching TAI/cycles and UCNT. This meets the pointwise
functional gate.

This result does **not** establish that the offset remained in range for 300
seconds: only 2/958 rows were strictly inside ±60 ps, with valid-read offsets
ranging from −4094 to +2533 ps. It also does not establish servo causality or
physical SMA/output-pin skew. The 300-second capture did not change production
controls or program/reset the boards. See the
[dashboard-equivalent capture report](EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930/REPORT.md)
and the [formal frozen Step 6 package](../../artifacts/milestones/step6_global_time/README.md).

A previous one-shot dashboard sample reported −3779 ps and was correctly
not-qualified at that instant; it is separate from, and does not invalidate,
the later pointwise capture. Earlier failed and partial phase investigations
remain preserved as historical diagnostic evidence below.

```text
STEP5_SLAVE_LOCK_STABILITY_300S       = PASS
STEP6A_GLOBAL_TIME_VALIDITY           = PASS
STEP6A_SAME_PPS_CONSISTENCY           = PASS (5/5 exact labels)
STEP6B_DUAL_BOARD_TRIGGER             = PASS (initial + re-arm, 0-cycle delta)
STEP6_FUNCTIONAL_POINTWISE_GATE       = PASS (2 consecutive samples at +59 ps)
STEP6_PHASE_OFFSET_300S_STABILITY     = NOT_ESTABLISHED
PHYSICAL_SMA_EDGE_SKEW                = NOT_EVALUATED
TIMING_CLOSED                         = NO (not a functional gate)
```

Prior capture and source audits remain available for diagnosis. Their sparse
in-range readings do not imply sustained lock, and separately acquired frames
do not establish control-loop causality. No PI/gain or servo adjustment is
part of this Step 6 pointwise milestone.
## Main evidence

- [Independent frozen-source reproduction](EXP-S6-MILESTONE-REPRO-20260927/REPORT.md)
- [Exact frozen-image strict-offset re-observation](EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/REPORT.md)
- [Servo-transition high-rate correlation plan](EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/PLAN.md)
- [Servo-transition high-rate correlation report](EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/REPORT.md)
- [Fast SSTAT/CKO capture plan](EXP-S6-SERVO-FAST-SSTAT-CKO-20260929/PLAN.md)
- [Fast SSTAT/CKO capture report](EXP-S6-SERVO-FAST-SSTAT-CKO-20260929/REPORT.md)
- [Interleaved CKO/DMS capture plan](EXP-S6-SERVO-INTERLEAVED-CKO-DMS-20260930/PLAN.md)
- [Interleaved CKO/DMS capture report](EXP-S6-SERVO-INTERLEAVED-CKO-DMS-20260930/REPORT.md)
- [UCNT-paired phase-context plan](EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/PLAN.md)
- [UCNT-paired phase-context report](EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/REPORT.md)
- [Slave-only microtrace plan](EXP-S6-SERVO-SLAVE-MICROTRACE-20260929/PLAN.md)
- [Slave-only microtrace reader](EXP-S6-SERVO-SLAVE-MICROTRACE-20260929/scripts/read_slave_servo_microtrace.tcl)
- [Slave-only microtrace report](EXP-S6-SERVO-SLAVE-MICROTRACE-20260929/REPORT.md)
- [Formal Step6 milestone package](../../artifacts/milestones/step6_global_time/README.md)
- [Historical end-to-end hardware run](EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md)
- [Digital evidence closure audit](EXP-S6-DIGITAL-MILESTONE-CLOSURE-20260922/REPORT.md)
- [Step6B post-fit timing evidence](EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922/REPORT.md)
- [Historical Step6 evidence summary and limits](STEP6-PASS-MILESTONE.md)

The historical end-to-end run used source commit `74dc28862653d306e0450cf437ba6d3a230d979d`
and the historical SOFs under
[`artifact-import/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/`](artifact-import/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/).
Those files are provenance/reference artifacts only. The current functional
PASS is based on the independently rebuilt SOFs and new hardware validation
captured in `EXP-S6-MILESTONE-REPRO-20260927/`.

## Dashboard tools

The active read-only dashboard remains in the current script tree:

- [`step1_6_dashboard.sh`](../../scripts/monitor/step1_6_dashboard.sh)
- [`read_step1_6_dashboard.tcl`](../../scripts/jtag/read_step1_6_dashboard.tcl)

It reports Step1–Step6 gates, link/lock state, and validity-gated TAI/cycles.
Its bounded `WAIT_FOR_GLOBAL_TIME_SECONDS` wait must not invent time values
before validity is established.

Create all new Step6 reproductions directly under `experiments/step6/EXP-.../`.
Step6A validates both boards' Global-Time/PPS validity and same-PPS
Master/Slave consistency. Step6B exercises one common future `(TAI, cycles)`
target and verifies one healthy firing per board. Matching digital labels do
not prove physical SMA/output-pin skew.
