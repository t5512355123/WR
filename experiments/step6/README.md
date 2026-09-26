# Step 6 — Global Time and Scheduled Trigger

Step 6 is the current research stage. Its historical functional evidence is
preserved in this directory; the independent frozen-source reproduction is
still pending. Do not treat the historical report or imported SOFs as the
formal milestone reproduction.

```text
HISTORICAL_STEP6A_GLOBAL_TIME_AND_SAME_PPS = PASS
HISTORICAL_STEP6B_DIGITAL_TRIGGER          = PASS
FROZEN_SOURCE_REPRODUCTION                 = PENDING
PHYSICAL_SMA_EDGE_SKEW                     = NOT_EVALUATED
```

## Main evidence

- [Historical end-to-end hardware run](EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md)
- [Digital evidence closure audit](EXP-S6-DIGITAL-MILESTONE-CLOSURE-20260922/REPORT.md)
- [Step6B post-fit timing evidence](EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922/REPORT.md)
- [Historical Step6 PASS summary and limits](STEP6-PASS-MILESTONE.md)

The end-to-end run used source commit `74dc28862653d306e0450cf437ba6d3a230d979d`
and the historical SOFs under
[`artifact-import/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/`](artifact-import/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/).
Those files are provenance/reference artifacts only; Step6 acceptance requires
fresh builds from `artifacts/milestones/step6_global_time/source/` and a new
hardware validation run.

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
