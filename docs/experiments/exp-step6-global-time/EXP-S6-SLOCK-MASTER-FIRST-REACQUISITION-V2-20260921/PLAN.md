# EXP-S6-SLOCK-MASTER-FIRST-REACQUISITION-V2-20260921

## Purpose

Retest the Master-first startup order without incorrectly requiring a
peer-dependent link status before the Slave is programmed.

## Fixed hardware and image

- Keep the currently programmed `ec1f25e8` Master boot; do not reprogram it.
- Reuse the exact Slave SOF from `ec1f25e8`:
  `7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e`.
- Do not compile, power-cycle, restart PTP, change mode, change fiber, or
  modify RTL, WRPC firmware, SoftPLL, timeout, retry, PI, threshold, PHY, or
  SI5340 behavior.

## Controlled sequence

1. Read the current Master for five coherent local-ready samples.  Require
   `SI_CONFIG_DONE`, `WR_READY`, `WR_RX_READY`, `WR_TX_READY`, `CPU_RESET_N`,
   `PTP_STATE=6`, `WR_DISABLE_VALID=0`, stable generation/reset counters, and
   trusted transport.  Record `CORE_TM_LINK_UP` and `CORE_LINK_OK`, but do not
   use them as this pre-Slave gate.
2. If local-ready passes, immediately program the exact Slave SOF and record
   the Master settle time, Slave program start, and Slave program completion.
3. Start two read-only observers immediately after Slave programming: one for
   each DE5a board.  For the first 30 seconds, require the full link gate on
   each board: all local-ready bits, `WR_RX_LOCKED_TO_DATA=1`,
   `CORE_TM_LINK_UP=1`, and `CORE_LINK_OK=1` for five consecutive samples.
4. If both link gates pass, continue the Slave observer to the 240 s S_LOCK
   deadline (with a 300 s maximum capture) and derive
   `LOCK_SUCCESS_COUNT = LOCK_POLLS - LOCK_UNLOCKED - LOCK_CALIB_FAIL`.

## Stop conditions

- Master local-ready failure before Slave programming:
  `INCONCLUSIVE_MASTER_STATE_LOST`; do not program Slave.
- Either board fails the post-Slave link gate for 30 seconds:
  `INCONCLUSIVE / FAIL_POST_SLAVE_LINK_ESTABLISHMENT`; do not claim an S_LOCK
  result.
- Link gate pass followed by `LOCK_SUCCESS_COUNT >= 1` and a transition from
  `WRS_S_LOCK` to `WRS_LOCKED` (or TX `LOCKED`) with 10 seconds of stable
  post-event evidence: `PASS_SLOCK_SUCCESS`.
- Link gate pass followed by `WR_S_LOCK_TIMEOUT` with zero successful polls and
  zero calibration failures: `FAIL_SPLL_NOT_LOCKED_BEFORE_SLOCK_DEADLINE`.
- Link gate pass followed by calibration failures: 
  `FAIL_T24P_CALIBRATION_BEFORE_SLOCK_DEADLINE`.
- Any transport error, unexpected reset/generation change, or SOF mismatch:
  `INCONCLUSIVE`.

This experiment can establish the S_LOCK acquisition boundary only.  It does
not claim Step6A Global Time validity and does not run Step6B.
