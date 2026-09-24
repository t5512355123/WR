# Step 3 milestone reproduction — plan

## Objective

Rebuild a self-contained JTAG source package, program the freshly rebuilt
Master and Slave images, and verify Step 3 WR parent/signaling handshake while
also rechecking the Step 1 and Step 2 prerequisites. This does not claim
SoftPLL lock, `PSTAT.locked`, or valid global time.

## Candidate and historical evidence

- Historical experiment: `EXP-WRPC-STEP3-FRESH-HEAD-20260819`.
- Historical experiment source commit: `fb8c926cfe37b82e86300117181a6ac01e1889e2`.
- Historical report claims full compile, successful Master/Slave programming,
  and 30-second runtime acceptance. Its referenced raw build/program/runtime
  files were not found in the current repository or at the reported old Pain
  path, so that report is candidate-selection evidence only.
- The Git diff from the reported Step 3 commit to the Step 2 source commit
  `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` contains only three documentation
  files. The frozen build-input package is based on the latter and records
  path-only packaging changes; it contains no functional changes from the
  historical JTAG design.
- The historical report's `fail_state=2` label is not accepted as proof of the
  current WR state. Source audit established that `fail_state` is written by
  `wr_handshake_fail()`. Current state is `WR_LOCAL state`, and the enum defines
  `WRS_S_LOCK=2`. `wrpc_spll_locking_enable()` increments the persistent
  `wr_lock_enable_count` upon entry to that locking path.

## Frozen candidate

The provisional package is:

```text
artifacts/milestones/step3_wr_handshake/source/
```

Its SHA256SUMS covers the complete 3,142-file source/build-input tree. It is
derived from the independently rebuilt Step 2 JTAG package; the source commit
comparison and all packaging/path changes must remain documented. No
production RTL/firmware behavior, board pins, clocks, reset sequencing,
QSFP-A lane, PHY, PTP, WR signaling, or SoftPLL controls may be changed.

## Build, program, and observation

1. Push this plan and candidate package on `feat/file_cleanup`.
2. On Pain, pull that exact commit and verify the source manifest before any
   build. Record tool versions and QSF/QIP dependency audit.
3. Clean-build firmware and Quartus Master and Slave from the package; retain
   full logs and MIF/SOF hashes. Both compiles must succeed.
4. Program fresh Master to `DE5 [1-11.1]`, then fresh Slave to
   `DE5 [1-11.2]`, matching the historical Step 3 order. Retain programmer
   output and image checksums. No power cycle, cable change, reset, PTP restart,
   or runtime control write is planned.
5. Capture read-only start/end snapshots and one 30-sample, 1-s interval
   JTAG time series per the existing `read_wb_timeseries_session.tcl` reader.
   Save every raw frame, including rejected frames/retries.
6. Run the existing Step 2 runtime analyzer on the same captures to verify
   Step 1/2 regressions, then run the Step 3 analyzer and source-backed
   criteria below.

## Acceptance criteria

All counted frames must be internally coherent (`FRAME_VALID=1`,
`PARENT_BLOCK_VALID=1`, `WR_STATE_BLOCK_VALID=1`,
`WR_SIGNAL_BLOCK_VALID=1`, and `WR_LOCK_BLOCK_VALID=1`). Rejected/retried frames
remain in raw evidence but do not count as accepted.

**Both boards — Step 1 and Step 2 regression gates:**

- SI configuration, PHY ready, RX ready, TX ready, TM link, and core link OK;
  CPU released; no RX/TX encoding-error status.
- Correct endpoint identity; Master `MODE=2/PTP=6`, Slave `MODE=3/PTP=9`.
- MiniNIC and PPSI PTP RX/TX counters advance over the observation window.
- No firmware fault, reset-generation change, or link drop in start/end capture.

**Slave — Step 3 WR handshake:**

- `foreign_count=1`, `best_index=0`, WR parent identified and calibrated.
- `WR_SIGNAL rx_msg=0x1001` (`LOCK`) and `tx_msg=0x1000` (`SLAVE_PRESENT`),
  with positive signaling counts.
- `WR_LOCAL state=2` (`WRS_S_LOCK`) observed in a valid frame, or a positive
  `wr_lock_enable_count` in a valid frame proving the state-entry hook ran.
- No signaling rejection associated with the observed handshake.
- At least 20 valid accepted Slave frames over the 30-s observation window;
  every accepted Slave frame must meet the persistent parent/signaling/
  lock-entry criteria. Master must have at least 20 valid accepted frames.

The `fail_state` diagnostic will be reported for context but is not an
acceptance substitute for current `WR_LOCAL state`. SoftPLL lock and
`time_valid=1` are explicitly outside Step 3.

## Evidence and promotion rule

Save evidence under this directory's `raw/build/`, `raw/program/`,
`raw/observe/`, and `analysis/`. `REPORT.md` and `SHA256SUMS` will be completed
after the fresh run. This remains `NOT_PASS` unless both clean builds, both
program operations, Step 1/2 regression gates, and Step 3 runtime gates all
pass. If a gate fails, preserve the capture, identify the first inactive
boundary, fix only the source-backed cause, and repeat Step 3; do not start
Step 4 or substitute a later-Step image.
