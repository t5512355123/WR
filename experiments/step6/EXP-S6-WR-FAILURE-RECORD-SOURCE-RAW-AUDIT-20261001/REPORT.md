# EXP-S6-WR-FAILURE-RECORD-SOURCE-RAW-AUDIT-20261001

## Verdict

~~~text
AUDIT = PASS (existing raw hash, row count, decoder, source path)
HARDWARE_ACTION = NONE
TCL_OBSERVER_MODIFIED = NO
PRODUCTION_SOURCE_OR_CONTROL_MODIFIED = NO
RAW_SHA256 = PASS
CAPTURE_ROWS = 741 / 741
FAILURE_EDGE = sample 738, low8 count 0 -> 1
FAILURE_REASON = 3 / WR_S_LOCK_TIMEOUT
AUTO_REARM = SOURCE_CONSISTENT, NOT PROVEN
EXTENSION_DISABLE = NO STICKY RECORD OBSERVED
SUCCESS_EVENT = NONE
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~

## Inputs and provenance

The audit used the previously committed raw capture; no new hardware read was
performed.

| Evidence | Verified value |
|---|---|
| Branch / audit baseline | feat/file_cleanup / 1b0cd82246ba98953fca80159db2194062f005ae |
| Raw observer file | EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001/raw/observe/20260930T194058Z-wr-lock-event-continuity.log |
| Raw SHA-256 | 9fc2da70c44d005e351a721057f26b2f9506e441d752b354fde8338b56197580 |
| Raw rows / required-valid rows | 741 / 741 |
| Capture checkout before programming | fa9a813274783e3974fbdf76b46130b18637a246 |
| SOF build repository commit | 9c9afa345c1de03760ec9ee07eb742888c3fa8fe |
| Frozen firmware source origin | 74dc28862653d306e0450cf437ba6d3a230d979d |
| Slave SOF SHA-256 / Quartus checksum | 13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19 / 0x30B1E229 |
| Master SOF SHA-256 / Quartus checksum | 697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a / 0x30B18F28 |

Both hashes match the saved build-info and programmer logs. The images were
built earlier from the frozen source at repository commit 9c9afa; the
1b0cd822 capture preparation did not compile. The checked-in
artifacts/milestones/step6_global_time/master.sof and slave.sof have different
hashes and are not substitutes for the images used in this capture.

## Source-backed register mapping

The frozen source maps the diagnostics as follows:

| Raw observer field | Source register | Correct meaning |
|---|---|---|
| WR_FAILURE_RAW | WDIAG_SERVO_RESTART_COUNT, byte offset 0x6c (base + 0x00100A00) | bits 0–7 failure-count low byte; bits 16–23 last failed WR FSM state; bits 24–31 last failed role; bits 8–15 are overlaid with disable metadata when the sticky disable record is valid |
| LOCK_RESULT_RAW | WR lock-result shadow at byte offset 0x8c (base + 0x00100A00) | bits 0–7 last result; bit 8 current lock-check; bits 9–15 last failure reason; bits 16–31 failure-time timer low16 |

The 0x6c low byte is the counter used by this observer. The source initially
packs a wider count there, but a valid sticky disable record overlays bits
8–15 with cause, valid, and PTP-state fields; therefore this audit does not
treat the whole low16 as a counter. When disable-valid is zero, the cause and
PTP-state bit values are not valid disable-event data.

In task-diags.c, the last reason is packed at bit 9 and timer low16 at bit 16
before wdiags_write_wr_lock_debug writes the word at 0x8c. The failure role,
state, and count are packed into the separate 0x6c word. The previous Tcl
observer incorrectly extracted reason bits 9–15 from 0x6c and called them
valid when disable-valid was zero. That decode was wrong; its reported
WR_FAILURE_REASON=0 is withdrawn. The Tcl was intentionally left unchanged in
this offline audit.

## Failure-window decode

The corrected decoder verified the raw file hash, required-row validity, and
the source-defined words:

| Sample | Elapsed | WR state | A6C raw: count / role / failed state / disable-valid | A8C raw: reason / timer low16 |
|---:|---:|---|---|---|
| 737 | 249431 ms | WRS_S_LOCK | 0 / not yet recorded / not yet recorded / 0 | 0 (UNKNOWN) / 0x0000 |
| 738 | 249767 ms | WRS_PRESENT | 1 / 2 (Slave) / 2 (S_LOCK) / 0 | 3 (WR_S_LOCK_TIMEOUT) / 0xB919 |
| 739–740 | 250103–250442 ms | WRS_PRESENT | unchanged | reason 3 and 0xB919 unchanged |

For sample 738:

- A6C was 0x02020001. The observer read it from 1790797508670 to
  1790797508681. Only the low-eight count, role, failed state, and
  disable-valid flag are used. Disable-valid is zero; cause and disable PTP
  state are therefore NA, not meaningful zero values.
- A8C was 0xB9190601. Its bit fields decode to last result 1, current
  check-lock 0, failure reason 3, and timer low16 0xB919. Reason and timer are
  in the same raw word. The result/check-lock bits describe the diagnostic
  writer's current fields, not necessarily lock state at the failure instant.
- The previous sample's timer low16 was 0x0000. The modulo-16-bit difference
  is 47385 ticks and the sampled low word increased numerically. Hidden full
  wraps between samples cannot be excluded. This is not host elapsed time; the
  timer scale/origin is not established.
- The A8C read has no dedicated begin/end timestamps in the saved row.
  Observer source order bounds it after REJECT_READ_END_MS=1790797508692 and
  before POLL_READ_BEGIN_MS=1790797508703 (11 ms). The A6C and A8C are
  sequential, separate reads, not an atomic cross-register snapshot.
- Row bracket was 1790797508623–1790797508958; WR_STATE_RAW was read at
  1790797508624–1790797508648. RX raw was 0x10010001 (ID 4097, count 1);
  TX raw was 0x10000002 (ID 4096, count 2).
- WR_STATE_RAW=0xA0408B5C decodes to current/next WR FSM state 1/1
  (WRS_PRESENT), WR mode 2 (Slave), parent-is-WR 1, and parent WR config 3
  (WR_M_AND_S). These are nearby context, not an atomic snapshot at the
  failure call.
- At that row, the context showed SoftPLL sequence state 4, Helper lock 0,
  Main disabled/unlocked, and PSTAT lock 0. The S_LOCK tail showed stage 4,
  retry 0, remaining 0, and equal sequence words. The observer/source defines
  this tail as context only; equal sequence values do not prove an atomic
  diagnostic snapshot.
- PTP state at the exact failure call was not captured. The A6C
  disable-PTP-state bits cannot substitute for it because disable-valid is 0.

The observer saw no source-backed S_LOCK-to-LOCKED handoff, WRS_LOCKED state,
or successful TX LOCKED message. Its raw stop token
NEW_FAILURE_RECORD_AND_TERMINAL_WR_EXIT means only that the configured
failure-plus-three-state-exit capture stop rule fired. Samples 738–740 were
WRS_PRESENT, which may be a re-arm state; the token does not establish
extension disable. The corrected event analyzer now returns
NEW_FAILURE_AND_STOP_POLICY_STATE_EXIT_BEFORE_EVENT for this raw stop token.

## Writer, re-arm, disable, and reset-path audit

Frozen-source audit found:

1. WR_FAIL_REASON_WR_S_LOCK_TIMEOUT is code 3. The S_LOCK state calls
   wr_handshake_fail_reason with that code when its timeout reaches zero.
   The A6C failed-state/role values are 2/2, matching S_LOCK/Slave. This
   strongly supports an S_LOCK timeout record, not a PLL root-cause diagnosis.
2. wr_handshake_fail_reason increments the failure counter, records last role,
   state, reason, and timer_get_tics(), then checks the narrow auto-rearm
   predicate. That predicate additionally requires PTP state PPS_SLAVE or
   PPS_UNCALIBRATED, WR role Slave, a WR parent, and parent config WR_MASTER
   or WR_M_AND_S. On a match it resets the WR process/servo, sets the next PTP
   state to UNCALIBRATED, enables the extension, and returns before the
   extension-disable writer.
3. The observed WR role, parent-is-WR flag, parent config, following
   WRS_PRESENT state, and disable-valid 0 are consistent with the re-arm
   branch. Because PTP state at the failure call is missing and the words are
   not atomic, auto-rearm is supported but not proven.
4. A sticky extension-disable writer sets disable-valid and records a cause;
   the captured A6C disable-valid is 0. No sticky extension-disable record
   was observed in these rows. This does not prove the exact control path by
   itself, but does not support terminal extension disable.
5. The failure globals have one source writer in wr_handshake_fail_reason.
   wrc_ptp_ppsi_init resets the counter/reason/timer globals; consequently,
   stable boot/reset signatures do not by themselves rule out a PTP-level
   reinitialization. The observed 0-to-1 edge and reason are relative to this
   capture's trusted baseline, not a claim about all time since physical boot.
   The sticky disable metadata is separately reset by WDIAGS initialization.

## Implementation and verification

Added a strictly offline decoder and regression tests under this experiment.
It fails closed on raw hash/row-count/required-row-validity mismatch, decodes
the fields above, preserves the missing A8C exact-read-bracket limitation,
and tests the frozen source and saved build/program provenance.

- Source/raw audit tests: 8 passed.
- Existing event-continuity analyzer tests: 10 passed, including the neutral
  stop-policy classification.
- Existing raw log: 741/741 rows accepted; failure edge at sample 738.
- No Tcl observer, production C/RTL, SOF, build input, or hardware state was
  changed by this audit.

## Conclusion and stop

Supported: one recorded WR_S_LOCK_TIMEOUT during this capture.

Supported but not proven: the subsequent state progression is consistent
with the source-defined Slave re-arm path.

Not supported by these rows: terminal extension disable, a confirmed successful
lock poll, or the underlying cause preventing SoftPLL lock.

Step 6 stable offset remains NOT ESTABLISHED. This audit is complete. Do not
start another capture, compile, or program until a fresh advisor direction.
