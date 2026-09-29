# Step 6 — Global Time and Scheduled Trigger

Step 6 is the current research stage, and its independent frozen-source
reproduction is complete. Historical failed, partial, and successful runs are
kept here as part of the research record; the formal result is the separate
2026-09-27 reproduction report and frozen milestone package.

```text
STEP5_SLAVE_LOCK_STABILITY_300S = PASS
STEP6A_GLOBAL_TIME_VALIDITY     = PASS
STEP6A_SAME_PPS_CONSISTENCY     = PASS (5/5 exact labels)
STEP6B_DUAL_BOARD_TRIGGER       = PASS (initial + re-arm, 0-cycle delta)
STEP6_FUNCTIONAL_MILESTONE      = PASS
PHYSICAL_SMA_EDGE_SKEW          = NOT_EVALUATED
SFP_CACHED_CALIBRATION_QUERY    = INCONCLUSIVE (guarded; no command sent)
TIMING_CLOSED                   = NO (not a functional gate)
```

## Main evidence

- [Independent frozen-source reproduction](EXP-S6-MILESTONE-REPRO-20260927/REPORT.md)
- [Formal Step6 milestone package](../../artifacts/milestones/step6_global_time/README.md)
- [Historical end-to-end hardware run](EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md)
- [Digital evidence closure audit](EXP-S6-DIGITAL-MILESTONE-CLOSURE-20260922/REPORT.md)
- [Step6B post-fit timing evidence](EXP-S6B-TIMING-QUERY-BOUNDARY-CORRECTION-20260922/REPORT.md)
- [Historical Step6 evidence summary and limits](STEP6-PASS-MILESTONE.md)

The end-to-end run used source commit `74dc28862653d306e0450cf437ba6d3a230d979d`
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
