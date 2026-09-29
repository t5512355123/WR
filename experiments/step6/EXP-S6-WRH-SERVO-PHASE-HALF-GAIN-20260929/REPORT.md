# EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929

## Status

`IMPLEMENTED_PENDING_PAIN_BUILD_AND_HARDWARE_VALIDATION`

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
- Pain build/program and post-change observation: pending.
- Step 6 end-to-end regression: pending.

## Verdict

Not yet Step 6 PASS. Do not claim Global Time or scheduled-trigger success
until the hardware acceptance checks in `PLAN.md` complete.
