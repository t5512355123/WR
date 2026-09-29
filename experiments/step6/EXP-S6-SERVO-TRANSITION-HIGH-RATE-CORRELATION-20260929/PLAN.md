# EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929

## Objective

Resolve the 10-second sampling blind interval around the single observed
`TRACK_PHASE` point by correlating the Slave servo state, signed phase offset,
SoftPLL signals, and sample-validity fields at the fastest rate supported by
the existing diagnostic reader. This is an observation-only experiment; it
does not attempt to tune or repair the control loop.

## Frozen baseline and scope

- Branch: `feat/file_cleanup`.
- Baseline documentation commit: `c433ba30d20362a8ebe77ed8f529fad04c3fd2d7`.
- Continue with the already programmed Step 6 frozen images; do not compile,
  program, reset, or power-cycle either board in this experiment.
- Frozen Master SOF SHA-256:
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Frozen Slave SOF SHA-256:
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Reuse only
  `artifacts/milestones/step6_global_time/source/scripts/jtag/read_wb_timeseries_session.tcl`;
  its SHA-256 is
  `16c0ec707ee2d020754423261f3f8f460c88e7cb369d762ea291a97c5e576de6`.
- Do not modify the frozen source snapshot, production firmware/RTL, SDC/QSF,
  servo threshold, PI/gains, timing settings, PPS setup, reset tree, or image.
- Do not contact or wait for any adviser.
- Never access the archived `/home/b10504072/04_WR_archive_step6_pass/` for
  writing.

## Source-audited signals and read semantics

The existing reader emits per-sample raw fields including:

- `WDIAGS_CKO` at `0x00100A40`: source-audited signed WR phase-offset value
  used by `WRH_WAIT_OFFSET_STABLE`.
- `WDIAGS_SSTAT` at `0x00100A08`: PTP/servo state, also decoded in the sample.
- `WDIAGS_DMS_H/L` at `0x00100A34/0x00100A38`.
- `WDIAGS_SETP` at `0x00100A44` and `WDIAGS_UCNT` at `0x00100A48`.
- Helper/Main lock flags, DAC/SoftPLL state, `CTRL_BEGIN/CTRL_END`, and
  `STEP5_SAMPLE_VALID` for the same reader row.

The script does call `write_source_data` to send each read request through the
existing in-system diagnostic mailbox. This is not a write to WR settings,
target/ARM control registers, or `DATA_SNAPSHOT`; source comments and address
audit confirm the reader only retrieves diagnostic registers. Do not run it
concurrently with the dashboard or another JTAG reader.

Rows are multi-register diagnostic windows, not atomic single-cycle snapshots.
Use the reader's begin/end validity fields and never infer single-cycle
causality across fields or across the sequentially sampled boards.

## Execution

1. On Pain, confirm the checkout is this experiment's pushed commit, clean,
   both DE5 JTAG cables are present, and no `quartus_stp`, programmer, or
   dashboard process is active. Verify the frozen source manifest and reader
   SHA-256. Run a single read-only dashboard smoke; require both boards to be
   enumerated and a trusted JTAG transport. Save preflight evidence under
   `raw/preflight/`.
2. Run the bounded 5-sample reader smoke. Continue only if both board sections
   finish, sample rows are emitted, and no reader/JTAG transport error or
   identity mismatch occurs. Save the timestamped complete output under
   `raw/observe/`.
3. Run one bounded capture of 60 samples per visible board, zero intentional
   inter-sample delay, and two reader retries. Use the timestamping wrapper;
   hard deadline is 30 minutes. Do not start any other JTAG observer until the
   process exits. Save complete output and process exit status under
   `raw/observe/`.
4. Stop after this capture. Do not automatically reprogram, reset, power-cycle,
   or launch an offset-stability run. Transfer evidence back to the laptop,
   verify hashes, analyze per-board row timing/validity and signal transitions,
   update `REPORT.md`, then push the result.

## Stop and interpretation rules

- Stop before capture for a wrong branch/commit, dirty checkout, source hash
  mismatch, missing cable, competing JTAG process, or failed trusted smoke.
- Stop the experiment on identity mismatch, repeated mailbox timeout, or a
  process that exceeds the 30-minute hard deadline; retain partial logs and
  mark the result `INCONCLUSIVE` if completeness/validity cannot be proven.
- A change in servo state, CKO, or SoftPLL counters is observational evidence
  only. Do not label it a cause unless the source and coherent sample fields
  support that conclusion.
- This experiment cannot establish the separate 300-second strict-offset
  acceptance by itself. Step 6 remains not established until its full stated
  acceptance window is directly measured.
