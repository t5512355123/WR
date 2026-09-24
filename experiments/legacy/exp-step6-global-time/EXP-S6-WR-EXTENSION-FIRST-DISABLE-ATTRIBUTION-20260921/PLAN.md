# EXP-S6-WR-EXTENSION-FIRST-DISABLE-ATTRIBUTION-20260921

## Purpose

Explain why the existing Slave state is `PTP_STATE=9` while the WR servo
state is zero.  The current `PTP_META=0x03020409` indicates PTP-only fallback
(`pdstate=FAILURE`, `extState=PTP`), so this experiment reads the firmware's
first-event sticky record to identify the event that disabled the WR
extension.

This experiment does not attempt Step6A recovery and does not run Step6B.

## Fixed hardware state

- Preserve the currently programmed Step6A image from `ec1f25e8`.
- Slave only: `DE5 [1-11.2]`.
- Ten samples maximum at 1 Hz.
- No FPGA programming, compile, power-cycle, PTP restart, mode command, or
  fiber operation.
- If the hardware resets or is reprogrammed before/during capture, classify
  the experiment as `INCONCLUSIVE` and do not restart it in the same session.

## Allowed changes

Only the following may change:

```text
scripts/jtag/read_step6_wr_extension_first_disable_attribution.tcl
scripts/experiment/step6_wr_extension_first_disable_attribution.py
scripts/tests/*
this PLAN/REPORT/raw directory
```

RTL, WRPC firmware, SoftPLL, PPS generator, reset tree, PTP configuration,
gain, threshold, timeout, and PHY are frozen.

## Evidence and source-backed decode

The observer reads the existing shadows:

```text
PTP_META       0x00100A5C
SSTAT          0x00100A08
WR_FAILURE     0x00100A6C
WR_LOCK_RESULT 0x00100A8C
WR_STATE       0x00100A4C
WR_RX/TX       0x00100A64/0x00100A68
WR_REJECT      0x00100A50
LOCK counters  0x00100A90..0x00100A9C
parent metadata 0x00100A74/0x00100A78/0x00100A80
```

The first-disable cause is `WR_FAILURE[10:8]`, validity is bit 11, and the
PTP state at disable is bits 15:12.  The pre-disable timer/pdstate/extState
are carried in the sticky SSTAT fields.  The WR handshake reason is
`WR_LOCK_RESULT[15:9]`.

## Stop and verdict rules

- Three coherent samples with valid cause `1`: stop as
  `PASS_PROTOCOL_TIMEOUT`.
- Three coherent samples with valid cause `2` and reason 1..7: stop as
  `PASS_HANDSHAKE_<REASON>`.
- Three coherent samples with valid cause `0`: stop as
  `INCONCLUSIVE_OTHER_CALLER`; do not claim a more specific caller.
- Three coherent fallback samples with `disable_valid=0`, current
  `pdstate=FAILURE`, and `extState=PTP`: stop as
  `FAIL_DIAGNOSTIC_CONTRACT`.
- Transport failure, reset change, or sticky-record change: stop immediately
  as `INCONCLUSIVE`.
- Otherwise stop after ten samples as
  `INCONCLUSIVE_NO_STABLE_FIRST_DISABLE_CLASS`.

Any causal attribution result remains `STEP6A=NOT_PASS`; this experiment only
narrows the upstream WR-extension failure boundary.
