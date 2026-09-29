# Step 6 — Global Time and Scheduled Trigger

The historical digital Step 6 scope was independently reproduced from frozen
source, but the current expanded Step 6 gate is not yet established. The
2026-09-29 exact-image re-observation captured one valid/stable Slave offset
point at -17 ps, but the next 10-second sample was +1165 ps; only 1/105
valid-time samples was within (-60,+60) ps, so this is not a sustained pass.
The later 60-row reader capture found no in-range offset and observed 55
`WAIT_OFFSET_STABLE` plus 5 `SYNC_PHASE` rows, with all five Step 5 lock
signals high. The 400-row fast capture improved the reader's internal row time
to a median 73.274 ms; all five Slave Step 5 locks remained high, but no sample
was strictly within ±60 ps and no `TRACK_PHASE` boundary was observed. Source
shows that this 60 ps gate is the immediate condition for entering
`TRACK_PHASE`; the deeper reason the measured offset stays outside it remains
open. The next diagnostic is a Slave-only compact SSTAT/CKO microtrace.
In addition to valid Global Time and the dual-board digital-trigger evidence, the
Slave must provide a valid/stable Global-Time sample with
`abs(WR_SERVO_OFFSET_PS) < 60`. Historical frozen-image values `-158 ps` and
`+135 ps`, and the later half-gain observation `-539 ps`, do not meet that
criterion. Historical failed, partial, and successful runs remain indexed
below as the complete research record.

```text
STEP5_SLAVE_LOCK_STABILITY_300S = PASS
STEP6A_GLOBAL_TIME_VALIDITY     = PASS
STEP6A_SAME_PPS_CONSISTENCY     = PASS (5/5 exact labels)
STEP6B_DUAL_BOARD_TRIGGER       = PASS (initial + re-arm, 0-cycle delta)
STEP6_HISTORICAL_DIGITAL_SCOPE  = PASS
STEP6_CURRENT_EXPANDED_GATE     = NOT_ESTABLISHED (requires valid/stable offset <60 ps)
PHYSICAL_SMA_EDGE_SKEW          = NOT_EVALUATED
SFP_CACHED_CALIBRATION_QUERY    = INCONCLUSIVE (guarded; no command sent)
TIMING_CLOSED                   = NO (not a functional gate)
```

## Main evidence

- [Independent frozen-source reproduction](EXP-S6-MILESTONE-REPRO-20260927/REPORT.md)
- [Exact frozen-image strict-offset re-observation](EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/REPORT.md)
- [Servo-transition high-rate correlation plan](EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/PLAN.md)
- [Servo-transition high-rate correlation report](EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/REPORT.md)
- [Fast SSTAT/CKO capture plan](EXP-S6-SERVO-FAST-SSTAT-CKO-20260929/PLAN.md)
- [Fast SSTAT/CKO capture report](EXP-S6-SERVO-FAST-SSTAT-CKO-20260929/REPORT.md)
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
