# EXP-S6-WRH-SERVO-FIRST-TRACK-FIXED-SETP-OPEN-LOOP-20260930

## Verdict

```text
INCONCLUSIVE_BASELINE_NOT_REACQUIRED
TRACK_PHASE_REACHED = NO
FIXED_SETP_INTERVENTION_EXERCISED = NO
15S_SMOKE = NOT_RUN
300S_DIAGNOSTIC = NOT_RUN
STABLE_OFFSET_300S = NOT ESTABLISHED
```

The candidate was built and programmed successfully, but the Slave did not
reach `TRACK_PHASE` during the acquisition observation. Therefore the latch
never engaged and this run provides no hardware evidence about fixed-SETP
behavior, CKO/DMS correlation, or Step 6 acceptance.

## Candidate and implementation

- Branch: `feat/file_cleanup`
- Candidate source commit: `9c9afa345c1de03760ec9ee07eb742888c3fa8fe`
- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`
- Baseline behavior: `/4 acquire + /4 track`, entry `abs(offset) < 60 ps`,
  ordinary exit `abs(offset) > 120 ps`.
- Diagnostic change: independent boot-lifetime one-shot SETP latch, with phase
  writes guarded in servo initialization, `SYNC_PHASE`, and `TRACK_PHASE`.
  The candidate does not force `wrh_tracking_enabled=0` and does not change its
  IPC setter. The `SYNC_PHASE` `WAIT_HW` flag/state transition remains outside
  the SETP guard.
- This matches the advisor's latest correction, including the additional
  `wrh_servo_init()` phase-write guard.

## Build and programming

Both firmware/FPGA builds completed successfully and both boards were
programmed in the prescribed order (Slave, then Master). The source and
milestone-artifact manifests were restored and verified after the build.

| Board | Result | SOF SHA-256 |
|---|---|---|
| Slave, `DE5 [1-11.2]` | Build PASS; program PASS | `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19` |
| Master, `DE5 [1-11.1]` | Build PASS; program PASS | `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a` |

Quartus reported `TIMING_CLOSED=NO` for both images. Timing closure is not a
criterion for this diagnostic and was not modified.

Pain raw preflight/build/program records were copied to this experiment's
`raw/` directory. All 25 copied files matched their Pain SHA-256 values.
See [`raw/SHA256SUMS`](raw/SHA256SUMS).

## Acquisition observation

- One read-only dashboard/JTAG session; interval 5 s; board comparison window
  1000 ms.
- Start: `2026-09-30 21:52:20 +08:00`.
- The prescribed 600-second deadline was `22:02:20 +08:00`. The sample at
  `22:02:21` still showed Slave `WAIT_OFFSET_STABLE`, offset `−956 ps`, and no
  `TRACK_PHASE`.
- The session was stopped with Ctrl+C at approximately
  `22:04:37 +08:00` (about 737 seconds after start, approximately 137 seconds
  beyond the planned maximum). The deadline overrun is recorded as a protocol
  deviation; the result at the deadline already met the stop condition.
- No `TRACK_PHASE` was observed. The final visible sample at `22:04:33` showed
  `WAIT_OFFSET_STABLE`, offset `−712 ps`, and Slave Global Time waiting because
  the PTP servo offset was not below 60 ps. Other visible samples included
  offsets `−607 ps`, `+3549 ps`, `+3572 ps`, and `−1008 ps`; these are examples,
  not a complete range or an independently preserved sample set.
- At the final sample, Master Step 1/2/4 and Global Time were PASS/VALID.
  Slave Step 1–4 were PASS, and Helper, Main frequency, Main phase, Main lock,
  and PSTAT were all 1. Slave Step 6 remained WAITING; its Global Time was
  invalid because the offset had not reached the strict `<60 ps` entry band.
- No reset, link loss, or Step 5 lock drop was reported in the visible
  dashboard output.

### Capture limitation

The continuous dashboard output was not persisted as a complete row-level raw
log. On Ctrl+C, the dashboard wrapper reported that its temporary
`capture.log` was missing and ended with `quartus_stp_rc=130` (the expected
interrupt code). The final visible sample and the deadline sample are
transcribed in [`raw/observe/monitor-console-summary.md`](raw/observe/monitor-console-summary.md);
this note is a summary, not a raw telemetry capture. Consequently, exact
sample counts, complete SSTAT distribution, and full offset extrema cannot be
claimed for this run.

## Interpretation and next boundary

This is not evidence that the fixed-SETP intervention failed: the Slave never
entered `TRACK_PHASE`, so the latch was never set. It is also not a Step 6
PASS. The only supported result is that the `/4 + /4` baseline was not
reacquired within the prescribed wait, despite the visible upstream gates and
five Step 5 locks remaining high.

No smoke or 300-second capture was started, and no gains, thresholds, DMS/PTP,
Step 5 controls, RTL, or hardware configuration were changed. A new production
change or another hardware run should wait for an updated experiment direction
that addresses failure to reacquire `TRACK_PHASE`.
