# EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929

## Status

`CANDIDATE_BUILT_PROGRAMMED; PHASE_FIX_HARDWARE_VALIDATION_NOT_REACHED`

## Baseline finding

The Slave showed healthy Step 1–5/SoftPLL lock signals while Global Time stayed
invalid. The existing read-only observer verified stable counter-bracketed
servo samples and two repeated post-action responses. In each pair, the
setpoint moved by the currently measured offset, then the next coherent offset
changed by approximately twice that amount in the opposite direction:

| Offset before (ps) | Setpoint delta (ps) | Offset after (ps) | Measured response delta (ps) |
|---:|---:|---:|---:|
| -2757 | -2757 | +2654 | +5411 |
| +2617 | +2617 | -2639 | -5256 |

The half-step model predicts residuals of approximately -52 ps and -11 ps,
respectively, within the existing 60 ps gate. This is a model prediction, not
yet a hardware pass.

## Change and verification

- Changed only `WRH_SYNC_PHASE` acquisition step to `offset_ps / 2`.
- Left the 60 ps gate and `TRACK_PHASE` fine-tracking algorithm unchanged.
- Offline tests: PASS, 2/2. The captured response slopes are between -1.9 and
  -2.1, and half-step model residuals are within the existing 60 ps gate.
- Pain pulled exact source commit `edd525a2104a7bc68c6db13fcaa1a1368c117095`.
- Both full Quartus builds succeeded. Fresh outputs were programmed, not the
  frozen milestone SOFs:
  - Master SHA-256 `83548dffe0350827ad9e314f03220175c47d6821f1c0a0f15a3b865be87cdb6a`
  - Slave SHA-256 `9e972ed4a858f3d21b105fc429a033f1267132ca0b4746d7430e78781f2bec0a`
  - Programmer reported one device configured, zero errors and zero warnings
    for each board. `TIMING_CLOSED=NO` for both; timing closure is not a
    functional acceptance criterion here.
- The 180-second read-only readiness wait did not reach the modified phase
  branch. Master remained Global-Time valid. Slave stayed at
  `WR_SERVO_STATE=SYNC_TAI`, `PTP_STATE=8`, with Step 2/4/5 not ready and the
  dashboard snapshot invalid. A follow-up 30-second coherent trace had 21
  coherent rows, 13 adjacent update pairs, no reset/generation change, and
  `SETP_PS=0` throughout. Thus the new `WRH_SYNC_PHASE` half-step was not
  exercised; this is an upstream-startup block, not a pass or fail of the
  changed phase-acquisition law.
- The raw `CKO` diagnostic is a signed 32-bit projection of the servo offset;
  it cannot resolve a multi-second TAI difference. The post-program capture
  summary and build/program identities are recorded under `raw/`.

## Verdict

`STEP6_PASS=NOT_ESTABLISHED`. The half-gain model is supported by baseline
captures, and the changed firmware is built and programmed, but the board did
not reach `WRH_SYNC_PHASE` during bounded post-program observation. Do not
claim the correction fixed Global Time or run scheduled-trigger acceptance on
this incomplete startup. The immediate next diagnostic boundary is why the
Slave remains in `SYNC_TAI`. Source inspection leaves several distinct gates
to separate: `readyForSync`, the SoftPLL `locking_poll`, and
`adjust_in_progress`; the current capture did not publish these individually.
Keep the programmed candidate in place and do not change the 60 ps threshold
or other control parameters while determining that boundary.
