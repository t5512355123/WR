# EXP-S6-SERVO-FAST-SSTAT-CKO-20260929

## Objective

Resolve whether very short `TRACK_PHASE` windows are being missed by the
approximately 579 ms median row interval of the previous reader. Use a narrow,
fast, framed diagnostic sample of the source-audited WR servo state (`SSTAT`),
signed phase offset (`CKO`), and existing lock/validity signals.

## Baseline and strict scope

- Branch: `feat/file_cleanup`.
- Baseline documentation commit: `3236caa2e144a95ceedb026c17e9b7f44bb66e4b`.
- Use the existing running Step 6 frozen-image session. Do not compile,
  program, reset, or power-cycle either board.
- Frozen Step 6 Master SOF SHA-256:
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Frozen Step 6 Slave SOF SHA-256:
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Do not change production C/RTL, SDC/QSF, servo threshold, PI/gains,
  timing settings, PPS setup, reset tree, or milestone source.
- Do not contact or wait for an adviser.
- Never write to or alter
  `/home/b10504072/04_WR_archive_step6_pass/`.

## Source-audited read set

The reader reuses the diagnostic mailbox transaction and packing from the
frozen `read_wb_timeseries_session.tcl`; only these fitted-design reads are
needed per row:

- Direct source probes 0 and 7: status and clock-activity brackets.
- `0x00100A04`: diagnostic command-stage begin/end framing.
- `0x00100A08`: SSTAT begin/end; bit 0 WR-state-valid, bits 8–11 servo state.
- `0x00100A40`: CKO begin/end; source-mapped signed WR phase offset in ps.
- `0x00100A0C`: PSTAT; bit 0 link, bit 1 SoftPLL lock.
- `0x00100ABC` / `0x00100AC4`: Helper/Main lock-state words.
- `0x00100A34`, `0x00100A38`, `0x00100A44`, `0x00100A48`: DMS high/low,
  SETP, and update count for contextual correlation.

The existing mailbox API uses `write_source_data` only to request a diagnostic
read. No Wishbone target/ARM control, WR setting, PPS setting, or
`DATA_SNAPSHOT` write is permitted. SSTAT and CKO are read at both ends of each
row; if SSTAT changes, preserve both states and mark the transition as bounded
inside that read window rather than flattening it into a stable state.
Mailbox row validity, servo-state validity, and the direct TIME/PPS/clock probes
are reported independently. A transiently unavailable direct probe must not
invalidate an otherwise framed mailbox row; only servo-state-valid rows may
contribute to state/offset analysis. This keeps Master rows useful for link and
lock context when its WR servo-state-valid bit is naturally low.

## Execution

1. On Pain, require this pushed experiment commit, a clean checkout before
   evidence creation, both intended DE5 cables, no active Quartus reader or
   programmer, and a valid frozen-source manifest. Run a one-shot dashboard
   smoke; require both boards and trusted JTAG transport, with a valid Slave
   servo/lock data path. Save preflight evidence.
2. Run the 10-row-per-board smoke. Continue only if both board sections finish,
   rows are well-formed, and no repeated mailbox timeout or JTAG error occurs.
3. Run 400 rows per board, zero intentional inter-row delay, two retries, and a
   15-minute hard deadline. The boards are sampled sequentially in one JTAG
   session; never claim cross-board simultaneity. Timestamp every output row.
4. Stop after the bounded capture. Do not tune or automatically reprogram.
   Transfer all raw logs to Laptop, verify byte-for-byte hashes, analyze both
   SSTAT/CKO boundaries and lock/validity fields, write the report, and push.

## Stop and result rules

- Stop before running for a branch/commit/source mismatch, missing cable,
  competing reader, or failed dashboard preflight.
- Retain partial logs and mark `INCONCLUSIVE` if the reader reaches its deadline,
  repeatedly times out, loses board identity, or produces too few valid framed
  rows to resolve state transitions.
- Any SSTAT edge inside a row is transition evidence only; the sampled CKO and
  lock fields are not atomic with it. Do not infer a root cause from temporal
  coincidence alone.
- This is a diagnostic capture, not Step 6 acceptance. A later separate
  observation must still establish the full accepted strict-offset window.
