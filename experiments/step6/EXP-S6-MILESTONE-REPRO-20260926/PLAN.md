# Step 6 frozen-source reproduction

Date: 2026-09-26

## Objective

Create and independently build a self-contained Step 6 source package from
hardware/firmware source commit `74dc28862653d306e0450cf437ba6d3a230d979d`.
Carry the current read-only Step 1–6 dashboard as a separately identified
host-side overlay. The dashboard overlay must not alter the hardware source.

## Acceptance sequence

1. Verify the package manifest maps every source blob to a package path and
   records every path-only transformation.
2. Run the frozen dashboard's offline tests.
3. On Pain, build Master firmware and Quartus project, then Slave firmware and
   Quartus project, directly from the frozen package.
4. Program the newly built Slave SOF, then Master SOF, on DE5 `[1-11.2]` and
   `[1-11.1]` respectively; retain complete logs.
5. Validate the current dashboard and direct Step 5 lock signals, then collect
   a continuous 300-second Step 5 stability window.
6. Reproduce Step 6A same-PPS Global-Time consistency and Step 6B dual-board
   scheduled digital trigger, including one repeat arm if the validated
   contract permits it.

## Guardrails

- Historical SOFs are references only and are not programming inputs for this
  reproduction.
- No production control, SoftPLL, PHY, reset, or timing constraints are to be
  changed in this packaging/reproduction phase.
- Timing closure and physical SMA edge skew are not Step 6 digital PASS gates;
  absent scope evidence, physical edge skew remains `NOT_EVALUATED`.
- If link or lock gates fail after programming, retain evidence and diagnose
  the frozen-source build/program chain before considering any physical action.

## Current verdict

```text
FROZEN_SOURCE_BUILD_PROGRAM = PASS
STEP5_DIRECT_LOCKS_300S     = PASS (189/189 samples; 359.311 s)
STEP6A_SLAVE_GLOBAL_TIME    = NOT_PASS (TIME_VALID=0 in 0/189 samples)
STEP6A_SAME_PPS             = NOT_RUN
STEP6B_DUAL_BOARD_TRIGGER   = NOT_RUN
STEP6_MILESTONE             = NOT_PASS
```

The immediate Step 6 boundary is Slave `WRH_WAIT_OFFSET_STABLE`: the measured
offset never entered the firmware's `<60 ps` gate. The 2026-09-27 coherent
read-only capture produced 205 valid samples, 194 counter-stable rows, and 104
adjacent servo-update pairs. No same-counter payload conflicts, Wishbone
timeouts, reset changes, or `TIME_VALID` samples occurred. The offset remained
outside `<60 ps` in every coherent row.

Eleven source-arithmetic matches were followed by measurable CKO movement. In
all eleven, the immediate CKO movement sign opposed the measured action offset;
eight reduced its absolute magnitude and three overshot to a larger absolute
residual. This does not support a globally reversed correction polarity, but
does not prove whether the phase shifter reached its requested target or why
the residual sometimes overshoots. Do not change production servo controls
based on this capture.

The next diagnostic is a sparse, read-only, publication-coherent read of the
existing F4L `phase_shift_current` alongside the already source-mapped WR servo
setpoint/offset. Keep the currently programmed image, do not reset/reprogram,
and treat the two diagnostic groups as non-atomic. Step 6A/6B remain unpassed
until their independent acceptance gates pass.
