# EXP-S6-SERVO-FAST-SSTAT-CKO-20260929 — report

## Verdict

```text
READ_ONLY_FAST_CAPTURE                  = PASS (400 accepted rows per board)
CAPTURE_PROCESS                         = PASS (exit 0; 0 reader errors)
SLAVE_STEP5_LOCKS_DURING_CAPTURE         = 400/400 samples
SLAVE_SERVO_STATE_VALID                 = 400/400 samples
SLAVE_TRACK_PHASE_OBSERVED              = NO
SLAVE_OFFSET_STRICTLY_WITHIN_60PS        = 0/400 samples
STEP6_EXPANDED_PHASE_OFFSET_GATE         = NOT ESTABLISHED
SERVO_TRACK_ENTRY_GATE                   = CONFIRMED; OUT_OF_RANGE_OFFSET_ORIGIN = OPEN
```

This is a successful diagnostic capture, **not** a Step 6 pass. It gives a
source-consistent explanation for why the sampled servo never reached
`TRACK_PHASE`: every valid Slave CKO value stayed outside the strict 60 ps
entry threshold. It does not yet explain why the WR offset remains hundreds to
thousands of picoseconds from zero, nor rule out a shorter-than-row transient.

## Scope and provenance

- Branch: `feat/file_cleanup`.
- Read-only capture reader at execution: commit `80c7bf71`; SHA-256
  `65cc6537281569cce831a754421e7c9f473d3c00f4a65fcb60654a98136c6dc3`.
- Analysis/reporting code was later updated and pushed through commit
  `a1f4abd2`; the capture log itself is unchanged.
- Frozen Step 6 Master SOF SHA-256:
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Frozen Step 6 Slave SOF SHA-256:
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- No FPGA compile, programming, reset, or power cycle was performed. These
  image hashes identify the previously validated files, not a bitstream hash
  read back from the live FPGA.
- The frozen-source verifier initially rejected three declared SFF-8636
  overlay rows because that transformation was not implemented. It was fixed
  to verify only the three named files against the exact independent-build
  commit `eedd3664`; all 3214 manifest rows, package hashes, Git blobs,
  transformations, and required inputs then passed on Pain.
- The archive `/home/b10504072/04_WR_archive_step6_pass/` was not accessed.
- No adviser was contacted.

## Preflight and smoke

The one-shot dashboard before capture showed both boards with Link/TM and
`TIME_VALID=1`, `PPS_VALID=1`. The Slave had Helper, Main frequency, Main phase,
Main lock, and PSTAT lock all asserted; servo state was `WAIT_OFFSET_STABLE`
and the point offset was `+390 ps`. Both JTAG cables were present, no competing
Quartus reader/programmer/dashboard process was found, and the source package
passed the integrity check above.

Two reader defects were caught and fixed by bounded smoke tests before the
accepted capture:

1. Tcl interpreted a bracketed hex-regex character class as command
   substitution. That first smoke failed before reading either target.
2. The next smoke incorrectly made direct TIME/PPS source-probe availability a
   prerequisite for mailbox rows; those probes were intermittent even while
   the dashboard and mailbox were healthy. Row, servo-state, and direct-probe
   validity were separated and preserved independently.

The final smoke passed with 10/10 accepted rows per board, 10/10 valid Slave
servo states, all five Step 5 lock bits high in 10/10 Slave rows, no reader
error, and no Quartus warning/error.

## Capture result

The single Quartus/JTAG session ran from `2026-09-29T14:34:32Z` to
`2026-09-29T14:35:32Z` (about 60 seconds). The boards were read sequentially;
there is no cross-board simultaneity claim. The capture produced 400 accepted
rows for each board. One Slave sample attempt was rejected by its command-stage
framing check and succeeded on retry; all 400 final Slave rows were valid.
Quartus exited 0 with no reader errors, timeouts, Quartus errors, or warnings.

| Measure | Master (`DE5 [1-11.1]`) | Slave (`DE5 [1-11.2]`) |
|---|---:|---:|
| Accepted mailbox rows | 400/400 | 400/400 |
| Valid WR servo-state rows | Not applicable | 400/400 |
| `WAIT_OFFSET_STABLE` at row start | Not applicable | 368/400 |
| `SYNC_PHASE` at row start | Not applicable | 32/400 |
| `TRACK_PHASE` at either row boundary | Not applicable | 0 |
| All five Step 5 lock bits high | Not applicable | 400/400 |
| Both TIME/PPS probes valid at both ends | 108/400 | 120/400 |
| CKO begin/end pairs strictly inside ±60 ps | Not applicable | 0/400 |
| CKO begin range / median | Not applicable | `-3945..+2210 ps` / `+790 ps` |
| CKO end range / median | Not applicable | `-3945..+2210 ps` / `+790 ps` |
| Within-row CKO delta min/max/median | Not applicable | `-1420 / +258 / 0 ps` |
| SSTAT changes bounded within a row | Not applicable | 5 |
| SSTAT transition between adjacent rows | Not applicable | 1 |
| Distinct DMS pairs / SETP values | 2 / 2 | 29 / 4 |
| UCNT first → last | `0 → 0` | `0x1AD0 → 0x1AED` |
| Reader-measured row duration, median | `73.260 ms` | `73.274 ms` |

The host timestamps attached to output lines arrived in bursts (Slave median
arrival interval `4.545 ms`, with a `503.820 ms` maximum) despite the internal
reader duration being about `73 ms` per row. Therefore output-arrival intervals
are **not** used as sample cadence; the reader's in-row duration and the full
capture start/end are the timing evidence. Rows remain sequential mailbox reads,
not atomic snapshots. The capture summary and all raw logs are covered by
[`raw/SHA256SUMS`](raw/SHA256SUMS).

The post-capture dashboard again showed both links and both Global-Time/PPS
valid, with all five Slave Step 5 lock signals high. The Slave remained in
`WAIT_OFFSET_STABLE` at `+368 ps`; Step 6 remained `NOT QUALIFIED`.

## Source-grounded interpretation

The source writes `WDIAG_CKO` from the signed `offsetFromMaster` in
`vendor/wrpc-sw/lib/task-diags.c:573-582`; the register is documented as clock
offset in ps in `vendor/wrpc-sw/include/hw/wrc_diags_regs.cheby:247-248`.
In `vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c:210-211`, the servo uses
the same `offsetFromMaster` quantity as `offsetMS`. In
`vendor/wrpc-sw/ppsi/include/hw-specific/wrh.h:56`,
`WRH_SERVO_OFFSET_STABILITY_THRESHOLD` is 60 ps. The
`WRH_WAIT_OFFSET_STABLE` branch enters `WRH_TRACK_PHASE` only when the absolute
remaining offset is `<60 ps`; otherwise it increments `missed_iters` and
returns to `WRH_SYNC_PHASE` at 10 misses (`wrh-servo.c:299-313`).

No accepted Slave row had either CKO boundary inside `(-60,+60) ps`; the
observed values instead ranged from `-3945` to `+2210 ps`. The repeated
`WAIT_OFFSET_STABLE` / `SYNC_PHASE` states are therefore consistent with the
source's strict entry gate and miss/reacquire behavior. This identifies the
immediate gate, not the deeper physical or servo cause that keeps CKO outside
the gate. The 73 ms row window also cannot exclude a brief sub-60 ps crossing
or a complete unobserved state excursion between the two SSTAT reads.

## Next experiment

Proceed with a Slave-only compact SSTAT/CKO read-only microtrace. Reduce each
row to command-stage begin/end plus SSTAT and CKO begin/end; retain independent
link/Global-Time/Step 5 dashboard checks immediately before and after. Target a
roughly 30 ms internal row duration and a bounded 300-second capture. Do not
change the frozen SOFs, servo threshold, PI/gains, timing constraints, or clock
settings. The purpose is to find whether a sub-60 ps or `TRACK_PHASE` interval
is being missed—not to tune control.
