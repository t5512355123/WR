# Step 6 — Global Time and Scheduled Trigger

The historical digital Step 6 scope was independently reproduced from frozen
source, but the current expanded Step 6 gate is not yet established. The
2026-09-29 exact-image re-observation captured one valid/stable Slave offset
point at -17 ps, but the next 10-second sample was +1165 ps; only 1/105
valid-time samples was within (-60,+60) ps. A five-minute Slave-only
microtrace later found 70 consecutive rows (~2.39 s summed row time) at
`TRACK_PHASE` and -32..-31 ps, plus 23 rows (~0.78 s) at +9 ps while
`WAIT_OFFSET_STABLE`; 93/8,779 rows had both CKO boundaries strictly inside
±60 ps. The tracking window ended after CKO moved from +92 ps to -3650 ps and
state returned to `SYNC_PHASE`.

The latest 300-second read-only correlation trace found 140 within-/adjacent-row
CKO transition brackets of at least 120 ps. Of these, 96 included both a servo
update-counter (`UCNT`) change and a corrected delay (`DMS`) change; 5 had a DMS
change without a UCNT change; and 39 had no UCNT, SETP, or DMS change in the
bracket. Only 7/3,763 rows had both CKO boundaries strictly inside ±60 ps.
Pre/post dashboards showed Link, Global Time, and all five Step 5 locks valid,
but the endpoint readings were +447 ps and -3801 ps. Therefore Step 6 remains
`NOT QUALIFIED`. `DMS` is corrected `delayMS = meanDelay + delayAsymmetry`;
the derived `CKO−DMS` residual is not an independent t1−t2 measurement, and
these sequential mailbox reads show correlation only. See the
[`offset/update correlation report`](EXP-S6-SERVO-OFFSET-UPDATE-CORRELATION-20260929/REPORT.md).
The next diagnostic should interleave CKO and DMS reads more tightly while
bracketing them with UCNT/SSTAT; do not infer causality or tune controls from
this capture.
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
