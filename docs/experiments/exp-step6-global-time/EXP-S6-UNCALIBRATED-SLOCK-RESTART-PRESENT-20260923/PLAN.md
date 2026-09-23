# EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923

## Objective

Make the recovered Slave re-enter the WR handshake from `PPS_UNCALIBRATED`,
then regain valid Global Time without disturbing the existing Step5 control.

## Evidence from the previous programmed image (`d84b828b`)

The previous change allowed S_LOCK timeout recovery from either
`PPS_SLAVE` or `PPS_UNCALIBRATED`, but the 360-second dashboard run showed
that the Slave remained in Step5 lock while Global Time stayed invalid:

- 36 consecutive complete lock observations from 2026-09-23 23:34:46 to
  23:40:35 (+08:00); Helper, Main frequency, Main phase, Main lock, and PSTAT
  were all `1` in every observed frame.
- The outer 360-second capture terminated during its next JTAG read, so that
  final partial frame is excluded from the continuity count.
- Slave Global Time remained `TIME_VALID=0`, `PPS_VALID=0`, and no valid
  snapshot was published. Master Global Time remained valid.
- A 10-sample read-only attribution had valid transport and stable reset
  counters, but repeatedly reported `PTP_STATE=8`, `SERVO_STATE=0`,
  `EXT_STATE=1`, WR Slave mode, all five Step5 lock flags `1`, and
  `ESCR_TM_VALID=0` / `ESCR_PPS_VALID=0`. The PTP receive counter advanced;
  the servo update counter remained at `239`.
- A second read-only liveness preflight confirmed the Slave was no longer in
  the old terminal fallback (`PTP_STATE=8`, `PD_STATE=3`, `EXT_STATE=1`), but
  this state did not recover Global Time.

## Source-level diagnosis

On an S_LOCK timeout in `PPS_UNCALIBRATED`, the prior re-arm set the WR
sub-state to `WRS_IDLE`. The PTP `PPS_SLAVE -> PPS_UNCALIBRATED` state-change
hook normally advances that idle state to `WRS_PRESENT`; however, when the
timeout occurs while already uncalibrated, no PTP state transition occurs and
that hook is not invoked. The parent-detection event was already consumed, so
the WR idle state has no event that restarts `SLAVE_PRESENT`. With
`wrModeOn` reset to false, `wr_ready_for_slave()` cannot promote the PTP state
back to `PPS_SLAVE`.

## Single source change

Keep all existing S_LOCK, role, and WR-parent guards. Select the WR restart
state according to the observed PTP state:

- Already `PPS_UNCALIBRATED`: enter `WRS_PRESENT` directly, causing the normal
  Slave handshake to send `SLAVE_PRESENT` again.
- `PPS_SLAVE`: preserve the existing `WRS_IDLE` path, which is advanced by
  the normal PTP state-change hook.

Do not alter Step5 PI/gain/threshold, SoftPLL, timeout values, PPS generator,
RTL, PHY, reset wiring, or timing constraints.

## Laptop-side validation and handoff

1. Run the new offline state-transition contract test and the existing Step6
   recovery regression tests.
2. Push the exact tested commit to `feat/file_cleanup`.
3. On Pain, pull that commit, build both boards, and program Slave then Master
   once. Record SOF hashes and programmer checksums.
4. Run the read-only dashboard and targeted attribution after the current
   session settles. Preserve full raw output.
5. Copy the raw evidence and final report into this experiment folder on the
   laptop and push those records to GitHub.

## Pass and stop conditions

- Step1/2 link and endpoint gates remain healthy on both boards.
- Step5's five direct Slave lock flags remain asserted for at least 300
  continuous seconds; classify this separately from Step6.
- Step6A requires valid/stable Slave time and PPS snapshots with advancing
  snapshot count, followed by a same-PPS Master/Slave comparison.
- Do not call Step6A PASS from Step5 lock alone or from one valid sample.
- If the Slave remains `PPS_UNCALIBRATED` or Global Time is still invalid
  after 120 seconds from healthy link plus Step5 lock, stop this run and use
  fresh source-backed attribution before any further code change.
- Stop immediately on reset/generation change, link loss, or invalid JTAG
  transport; preserve the raw evidence and record the exact boundary.
