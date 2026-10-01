# Step 6 — Global Time and Scheduled Trigger

**Current revised acceptance: PENDING 300 sampled seconds of `TIME_VALID=1` on
each DE5a board.** For both Master `1-11.1` and Slave `1-11.2`, every sampled
`STATUS_TIME_VALID` must remain 1 across a sample-to-sample span of at least
300,000 ms. Snapshot flags, PPS validity, TAI/cycle payload or monotonicity,
Step 1/link, Step 5 locks, phase offset, and timing closure are diagnostic only.
The boards are observed sequentially; this acceptance does not claim same-cycle
TAI equality or physical output skew. See the
[current experiment plan](EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001/PLAN.md).

The previous pointwise dashboard-equivalent phase gate is historical evidence,
not the current acceptance criterion.
The frozen Step 6 source/images were independently rebuilt and programmed;
historical evidence also confirms valid Global Time on both boards, five
matching common PPS labels, and two repeatable dual-board scheduled digital
triggers.

The latest historical read-only 300-second Slave capture explicitly checked
the complete dashboard Step 1 gate, valid/stable Global Time, all five Step 5
lock signals, and strict `abs(CKO) < 60 ps`. Step 1, Global Time, and all five
lock signals were high in 958/958 rows. Two consecutive sampled rows (#91–92,
296 ms apart) reported +59 ps, matching TAI/cycles and UCNT. This met the
previous pointwise phase criterion only.

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
STEP6_PREVIOUS_POINTWISE_PHASE_GATE   = PASS (historical; 2 consecutive +59 ps samples)
STEP6_TIME_VALID_300S                 = NOT_ESTABLISHED (revised target pending)
STEP6_PHASE_OFFSET_300S_STABILITY     = NOT_ESTABLISHED
PHYSICAL_SMA_EDGE_SKEW                = NOT_EVALUATED
TIMING_CLOSED                         = NO (not a functional gate)
```

Prior capture and source audits remain available for diagnosis. Their sparse
in-range readings do not imply sustained lock, and separately acquired frames
do not establish control-loop causality. No PI/gain or servo adjustment is
part of this Step 6 pointwise milestone.
## Main evidence

## Historical sustained-offset investigation (not a current pass gate)

The Step 6 pointwise milestone above is not a 300-second stable-offset pass.
The latest full-acquisition + /12 tracking + 4× fallback-guard experiment
completed a 300-second diagnostic with 0/857 accepted CKO rows strictly
inside ±60 ps, and no TRACK_PHASE state was observed. Its report is
[EXP-S6-WRH-SERVO-FULL-ACQUIRE-TRACK-TWELFTH-GUARD-FOURX](EXP-S6-WRH-SERVO-FULL-ACQUIRE-TRACK-TWELFTH-GUARD-FOURX-20260930/REPORT.md).

The next controlled candidate retains the measured quarter-step acquisition
and original 2× guard, changing only TRACK_PHASE correction from /4 to /8.
See the
[quarter-acquire / eighth-track plan](EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-EIGHTH-TRACK-20260930/PLAN.md).
That candidate built and programmed successfully, but its 30-minute
dashboard observed 0/180 Slave offsets strictly inside ±60 ps; it remained
in `WAIT_OFFSET_STABLE`/`SYNC_PHASE`, so the changed tracking branch was not
exercised. The short interleaved diagnostic also stopped on invalid Global
Time and is not a pass. See its
[report](EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-EIGHTH-TRACK-20260930/REPORT.md).
The eighth-acquire/eighth-track candidate was built and programmed from
`e30b7221c07adcf720dff85e2336d781aec7b502`. Its 30-minute dashboard produced
179 paired frames: both boards' Step 1/link gates and all five Slave Step 5
locks remained high, but the Slave offset was never strictly inside ±60 ps
(range −3838 to +5268 ps), and `TRACK_PHASE` was never reached. A subsequent
interleaved smoke used `phase_context=0`, saw Global Time invalid in all five
rows, and stopped before the minimum smoke gate; no 300-second diagnostic was
run. Step 6 stable offset remains NOT ESTABLISHED. See the
[eighth-acquire/eighth-track report](EXP-S6-WRH-SERVO-EIGHTH-ACQUIRE-EIGHTH-TRACK-20260930/REPORT.md)
and [plan](EXP-S6-WRH-SERVO-EIGHTH-ACQUIRE-EIGHTH-TRACK-20260930/PLAN.md).

The first-TRACK fixed-SETP candidate was built and programmed, but the Slave
did not reacquire `TRACK_PHASE` within the 600-second deadline. The run is
`INCONCLUSIVE_BASELINE_NOT_REACQUIRED`; its one-shot latch was never exercised,
so no smoke or 300-second capture was run. The dashboard was stopped about
137 seconds after the planned deadline, a protocol deviation recorded in the
[report](EXP-S6-WRH-SERVO-FIRST-TRACK-FIXED-SETP-OPEN-LOOP-20260930/REPORT.md).
No tuning change followed. See the
[experiment plan](EXP-S6-WRH-SERVO-FIRST-TRACK-FIXED-SETP-OPEN-LOOP-20260930/PLAN.md).
The quarter-step report's SSTAT 4/5 labels were corrected against the source
enum; raw data and numeric counts did not change.

The next `/4` acquisition + `/4` track candidate added an in-band hold: below
60 ps it held SETP and skipped `adjust_phase()`. It reached `TRACK_PHASE`,
valid Global Time, and all five Step 5 locks. Two 15-second read-only smokes
then found coherent, UCNT-matched CKO rows outside ±60 ps (5/18 and 13/21
accepted rows respectively); the first also had fewer than 20 accepted rows.
The candidate therefore failed the smoke gate and no 300-second capture was
run. This does not establish Step 6 sustained offset stability. See the
[in-band hold/deadband report](EXP-S6-WRH-SERVO-TRACK-INBAND-HOLD-DEADBAND-20261001/REPORT.md)
and [plan](EXP-S6-WRH-SERVO-TRACK-INBAND-HOLD-DEADBAND-20261001/PLAN.md).

The current diagnostic candidate adds a boot-lifetime latch intended to
freeze phase SETP at the first successful TRACK entry and guard every servo
phase-write path. It built and programmed successfully from `a62c264d`, but
the Slave remained in `SYNC_TAI` for the bounded readiness run: 88/88 paired
dashboard samples showed no Helper/Main lock, invalid Slave Global Time, and
no `TRACK_PHASE`. The latch was therefore never exercised; no smoke or
300-second CKO capture was run, and the result is inconclusive about fixed
SETP. The dashboard ran about 49 seconds beyond its planned 600-second
post-program deadline, which is documented in the
[fixed-SETP report](EXP-S6-WRH-SERVO-TRACK-ENTRY-FIXED-SETP-20261001/REPORT.md).

The source-backed, read-only Slave lock/admission trace on the programmed
fixed-SETP candidate completed 300 seconds with 888/888 valid rows. All five
Step 5 lock bits stayed high, but Servo state was `WAIT_OFFSET_STABLE` for 819
rows and `SYNC_PHASE` for 69; it never entered `TRACK_PHASE`. The WR admission
state stayed `WRS_IDLE`, with no source-backed admission event. This shows the
phase servo is the immediate unresolved boundary, but does not reveal whether
CKO crossed its strict threshold because the trace did not sample CKO/DMS/SETP.
The first same-publication-frame attempt stopped after five untrusted rows:
the diagnostic epoch changed in all 5/5 rows (`DIAG_EPOCH_STABLE=0`), so no
CKO/DMS/SETP pair was accepted despite valid raw reads. The next read-only
attempt will use the observer's separate-frame mode with an exact UCNT match,
without changing controls, resetting, or reprogramming. See the
[pre-TRACK attribution report](EXP-S6-FIXED-SETP-PRETRACK-LOCK-ATTRIBUTION-20261001/REPORT.md),
[plan](EXP-S6-FIXED-SETP-PRETRACK-LOCK-ATTRIBUTION-20261001/PLAN.md), and
[same-frame diagnostic report](EXP-S6-PRETRACK-COHERENT-CKO-SETP-20261001/REPORT.md),
[same-frame plan](EXP-S6-PRETRACK-COHERENT-CKO-SETP-20261001/PLAN.md),
[UCNT-paired diagnostic plan](EXP-S6-PRETRACK-UCNT-PAIRED-CKO-SETP-20261001/PLAN.md),
[fixed-SETP latch plan](EXP-S6-WRH-SERVO-TRACK-ENTRY-FIXED-SETP-20261001/PLAN.md).

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
