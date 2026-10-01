# EXP-S6-PRETRACK-COHERENT-CKO-SETP-20261001

## Objective

On the unchanged, already-programmed fixed-SETP candidate, measure the phase
servo's actual same-publication-frame CKO, DMS, SETP, SSTAT, and UCNT while
the five Step 5 lock flags are currently high and SSTAT has been observed to
alternate between `WAIT_OFFSET_STABLE` (5) and `SYNC_PHASE` (3).

This diagnostic answers whether CKO ever reaches the strict `(-60,+60) ps`
entry band and whether SETP/state behavior moves with the observed CKO/DMS
values. It is not a fixed-SETP smoke: the one-shot latch is still not known to
have fired, and SSTAT has not reached `TRACK_PHASE`.

## Frozen image/session

- Pain repo: `/home/b10504072/04_WR`, branch `feat/file_cleanup`.
- Laptop/Pain sync commit: to be recorded after this plan is pushed.
- Runtime firmware/FPGA source commit: `a62c264dbbfc15b31c316188dd7f851d28ec2a6d`.
- Slave SOF SHA-256: `5af7150671dfb293acd82c68f47df9688fc1f23d40cf912ed3c6764467754018`.
- Master SOF SHA-256: `9a0f1087c0dd75330c94cd7f24780359d4c3d89dacd7c207d734e29568d721c5`.
- No reset, reprogram, or power cycle has occurred since these images were
  programmed. Keep this live session; do not rebuild or reprogram.

The wrapper verifies the saved build source and both SOF hashes, cable
presence, and absence of another `quartus_stp` before starting the single
reader.

## Read-only capture

Use the existing observer with its same-WDIAGS-frame context mode:

```bash
quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl \
    30000 100 1-11.2 1
```

The wrapper runs the 30-second capture with a 90-second external watchdog and
stores the full log/checksum under this experiment's `raw/observe/`.
`phase_context=1` attaches CKO and DMS/SETP/SSTAT/UCNT to the same WDIAGS
publication frame. Cross-frame/control-cycle causality is still not claimed.

Capture/report these items separately:

- requested/actual row cadence, `READS_VALID`, `COHERENT`, diagnostic epoch
  stability, phase-context/frame validity, and UCNT match;
- CKO strict-band rows and full range, retaining every out-of-band sample;
- DMS range, SETP range/distinct values, and `SSTAT` distribution;
- Step 1, Global Time, all five Step 5 lock flags, reset signatures, and read
  errors.

The existing fixed-SETP analyzer may be used to report coherent rows and
numeric summaries, but a smoke/pass label from it is not applicable unless
the row gates are met. In this run, state 3/5 rows are diagnostic context,
not fixed-SETP evidence.

## Stop and interpretation rules

Do not open another JTAG reader concurrently. Stop on SOF mismatch, missing
cable, active competing reader, fatal JTAG/Tcl error, reset change, Step 1
loss, or five consecutive untrusted rows. Otherwise stop at 30 seconds.

This capture can establish whether qualified same-frame CKO samples entered
the threshold during the current WAIT/SYNC cycle. If none do, it supports the
direct threshold-not-met boundary for this window. If samples enter the strict
band while SSTAT remains 3/5, that motivates a source audit of the exact
WAIT→TRACK predicate and its sampling/update cadence. Neither outcome alone
proves measurement or controller causality.

Do not change controller code or run a 300-second Step 6 capture from this
diagnostic. Preserve raw data, analyze on Laptop, update the report/index,
push, sync Pain, and stop before another hardware action.
