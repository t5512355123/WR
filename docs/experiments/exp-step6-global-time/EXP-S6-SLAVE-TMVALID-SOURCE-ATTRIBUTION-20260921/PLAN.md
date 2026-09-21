# EXP-S6-SLAVE-TMVALID-SOURCE-ATTRIBUTION-20260921

## Purpose

Attribute the current Slave `STATUS_TIME_VALID=0` state without destroying
the already-programmed failure state.  The Master result from the previous
capture is the reference; this experiment tests whether the missing valid bit
is caused by WR/PTP/servo progression, a reset/re-initialization, or a
cross-layer export/mapping mismatch.

This is a diagnostic experiment, not a Step6A or Step6B pass claim.

## Fixed baseline

- FPGA image: the existing Step6A image from source commit `ec1f25e8`.
- No RTL, firmware, MIF, PTP setting, boot script, SoftPLL parameter, reset
  tree, PPS register, or JTAG control write is allowed.
- No FPGA reprogramming and no power-cycle are allowed.  The previous run
  showed a valuable state: link healthy, `pps_valid=1`, but `time_valid=0`.
- Observer: `scripts/jtag/read_step6_tmvalid_source_attribution.tcl`.
- Capture: 1 Hz, maximum 180 seconds per board.

## Correlated fields

Each row preserves the source-side and exported-side evidence together:

- Top-level status: link/ready, `STATUS_TIME_VALID`, `STATUS_PPS_VALID`.
- PPS generator: `PPS_CR`, `PPS_ESCR`, `ESCR_TM_VALID` (bit 3),
  `ESCR_PPS_VALID` (bit 2).
- WR protocol: `WDIAGS_PTP`, `PTP_META`, `WDIAGS_SSTAT`/`SERVO_STATE`,
  `WDIAGS_UCNT`, `CKO`, foreign/parent metadata.
- Step5 preservation: Helper/Main/PSTAT lock fields.
- Reset evidence: boot generation and CPU/WR/SI sticky counters.
- Step6 evidence: live TAI/cycles and frozen snapshot count.

## Stop and verdict rules

- `RECOVERY_PASS`: Master/Slave remain healthy; Slave is PTP state 9 and servo
  state 4 for at least 10 samples; `ESCR_TM_VALID=1`, exported
  `STATUS_TIME_VALID=1`, Step5 locks remain set, no reset occurs, and at least
  two frozen snapshots are observed.  This is the only path that can advance
  toward Step6A.
- `MAPPING_EXPORT_FAIL`: `ESCR_TM_VALID=1` while exported
  `STATUS_TIME_VALID=0` for 3 samples.
- `RESET_INIT_FAIL`: boot/reset evidence changes and remains changed for the
  five-sample confirmation window.
- `TIMING_OUTPUT_CONTROL_FAIL`: Slave is PTP/servo complete, UCNT advances,
  PSTAT and Step5 locks remain set, but both TM-valid fields remain zero for
  10 samples.
- `FAIL_PTP_SERVO_NOT_COMPLETE`: link is healthy but the Slave remains outside
  PTP state 9/servo state 4 with both TM-valid fields zero for 10 samples.
- Otherwise, after 180 seconds: `TMVALID_ATTRIBUTION_INCONCLUSIVE`.

No Step6B trigger is implemented or run in this experiment.

## Execution record

The capture, raw checksum, analyzer JSON, and final report are added only
after the read-only Pain session completes.
