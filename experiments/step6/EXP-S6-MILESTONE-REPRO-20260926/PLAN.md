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
read-only captures produced 205 samples (the first capture) and 201 samples
(the F4L follow-up); the latter had 191 counter-stable rows and 99 adjacent
servo-update pairs. Across both captures there were no same-counter payload
conflicts, Wishbone timeouts, reset changes, or `TIME_VALID` samples.

Eleven source-arithmetic matches were followed by measurable CKO movement. In
all eleven, the immediate CKO movement sign opposed the measured action offset;
eight reduced its absolute magnitude and three overshot to a larger absolute
residual. This does not support a globally reversed correction polarity, but
does not prove whether the phase shifter reached its requested target or why
the residual sometimes overshoots. Do not change production servo controls
based on this capture.

The sparse F4L follow-up read 23/23 publication-coherent frames; 20 also had a
matching servo update counter and 18 could be joined to a coherent servo row.
In 15/18 joins, internal SoftPLL `phase_shift_current` was within 1 ps of the
WR servo setpoint. The other three were sparse target-transition observations
(+3236, +386, and -2171 ps). However, the WR phase offset remained outside
`<60 ps` in all 191 coherent rows and `TIME_VALID` stayed 0 in all 201 rows.
This indicates that the internal SoftPLL phase-shift state usually catches up
to its requested target; it does not prove electrical clock-phase movement.

The subsequent read-only F4L PI-response capture is complete. It collected 199
rows, 193 counter-stable rows, and 110 adjacent servo-update pairs, with no
counter conflicts, reset changes, Wishbone timeouts, or invalid reads. All 15
joined F4L rows were Main phase-branch rows with the phase detector called,
in-band and locked before/after, and a DAC write; none were clamped or VCO
frozen. `TIME_VALID` remained 0 and no coherent CKO sample entered the 60 ps
gate. This rules out a missing Main phase-branch invocation in the sampled
interval, but does not prove electrical output-phase movement.

A further read-only capture added the already-published raw round-trip delay
(`MU`), corrected one-way delay (`DMS`), and asymmetry (`ASYM`) to the guarded
servo observation. It is summarized in the reproduction report. Both captures
remain descriptive: the current image/session is unchanged, and Step 6A/6B
remain unpassed until their independent acceptance gates pass.

Source audit located read-only SNMP GETs for the four WR fixed-latency values
(`delta_txm`, `delta_rxm`, `delta_txs`, `delta_rxs`) in picoseconds. No DE5
management IP is evidenced in the experiment records, so no guessed-address
query or LAN scan is allowed. Next, verify the JTAG VUART path for the
side-effect-free firmware command `ip get`, capture the active board address,
and only then attempt bounded SNMP GETs if reachability is established.
