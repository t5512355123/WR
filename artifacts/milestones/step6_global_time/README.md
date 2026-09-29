# Step 6 — Global Time and dual-board scheduled digital trigger

**Historical digital-trigger scope: PASS.** The frozen-source images were
independently rebuilt and programmed, both boards reported valid Global Time,
Master and Slave matched on five common PPS labels, and both boards fired the
same future digital trigger twice at exactly matching TAI/cycle labels.

**Current expanded Step 6 acceptance: NOT ESTABLISHED.** In addition to the
gates below, the Slave must report a valid/stable Global-Time snapshot while
`abs(WR_SERVO_OFFSET_PS) < 60`. Retrospective reads of the 2026-09-27
frozen-image raw dashboards found `-158 ps` after the 300-second Step5 series
and `+135 ps` in the final post-rearm dashboard. Global Time was valid in both
captures, but neither offset meets the strict limit. A later 2026-09-29 run on
a different half-gain image observed `-539 ps` and then larger offsets; it
also does not qualify the expanded criterion.

## Acceptance evidence

| Gate | Result |
|---|---|
| Step 5 lock regression on Slave | PASS: 301/301 accepted samples; Helper, Main frequency, Main phase, Main lock, and PSTAT were locked in all 301 samples. The observer requested a 1000 ms cadence. |
| Global Time on both boards | PASS: valid/stable snapshots with `TIME_VALID=1` and `PPS_VALID=1`. |
| Slave WR servo phase offset | NOT PASS: retrospective frozen-image samples were -158 ps after the 300-second series and +135 ps after re-arm; neither is strictly within ±60 ps. Continuous offset stability was not measured. |
| Same-PPS agreement | PASS: five common TAI labels matched exactly; maximum difference was 0 cycles (0 ns). |
| First scheduled digital trigger | PASS: Master and Slave each fired once at TAI 3094, cycle 62,500,000; measured digital label difference 0 cycles (0 ns). |
| Re-arm repeatability | PASS: both fired again at TAI 3679, cycle 62,500,000; each fire counter reached 2; second measured digital label difference 0 cycles (0 ns). |
| Post-fire health | PASS: link, Global Time, and Slave lock signals remained valid; reset/generation counters did not change in the captured post-fire windows. |

The 300-second lock series was sequential by board. The Master is not expected
to run the Slave SoftPLL and is reported as `NEVER_LOCKED` by that observer;
the Step 5 regression gate is the Slave result, `STABLE_LOCK_CANDIDATE`, with
301 valid samples and no unlocked sample. The raw log records the requested
cadence and complete job start/end times.

## Provenance and frozen files

- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Dashboard/source overlay commit: `3b3a8ec52668d0c60550451ef1780539f7c93fd7`.
- The frozen `source/` tree is kept byte-identical to its source manifest and
  the checked-in frozen SOFs. Experimental servo/control variants belong in
  their own experiment source snapshot or patch; do not edit this frozen tree
  in place. The unaccepted half-gain candidate is documented separately in
  `experiments/step6/EXP-S6-WRH-SERVO-PHASE-HALF-GAIN-20260929/REPORT.md` and
  was built from source commit `edd525a2104a7bc68c6db13fcaa1a1368c117095`.
- Independently rebuilt from `artifacts/milestones/step6_global_time/source/`
  using Quartus Prime Standard Edition 17.0.0 Build 595 and the recorded
  RISC-V toolchain.
- Master SOF: [`master.sof`](master.sof), SHA-256
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Slave SOF: [`slave.sof`](slave.sof), SHA-256
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Both files are exact copies of the independently built images; they were
  programmed Slave first, then Master. Programmer logs report one device
  configured per board, zero errors, and zero warnings.
- `TIMING_CLOSED=NO`; timing closure is not a functional Step 6 gate.

## Rebuild and program

From the repository root on Pain:

```sh
cd artifacts/milestones/step6_global_time/source
bash firmware/scripts/build_master_firmware.sh
bash scripts/build/build_master.sh
bash firmware/scripts/build_slave_firmware.sh
bash scripts/build/build_slave.sh
```

To program the frozen milestone SOFs rather than rebuild outputs, remain in
the `source/` directory and use the matching wrappers:

```sh
SOF=../slave.sof CABLE='DE5 [1-11.2]' bash scripts/program/program_slave.sh
SOF=../master.sof CABLE='DE5 [1-11.1]' bash scripts/program/program_master.sh
```

Run the read-only Step 1–6 dashboard from the repository root:

```sh
bash scripts/monitor/step1_6_dashboard.sh
```

Verify the frozen source with `cd artifacts/milestones/step6_global_time/source`
then `sha256sum -c SHA256SUMS`; verify the milestone files from this directory
with `sha256sum -c SHA256SUMS`.

## Limits and outstanding diagnostics

- The trigger comparison is based on the two boards' latched digital TAI/cycle
  labels. No oscilloscope measurement was made, so physical `SMA_CLKOUT` or
  output-pin skew remains **NOT EVALUATED**.
- The guarded `sfp params` cached-state query was attempted twice. Both
  attempts stopped before sending a firmware command because the shell-ready
  observer reported a non-idle persistent command stage. Therefore this
  experiment does not claim a direct CLI confirmation of the QSFP serial ID or
  calibration-database match; it does not invalidate the independently
  observed Global-Time/trigger gates.
- The live dashboard now fails Step 6 closed on the Slave unless the reported
  signed WR phase offset is a valid integer strictly inside +/-60 ps. The
  historical digital-trigger pass remains valid for its original scope, but
  cannot be presented as a pass under this expanded criterion until the
  frozen-image offset gate is captured.
- The runtime-trigger observers use target/ARM source writes only. They do not
  compile, program, reset, restart PTP, or change PPS configuration.

## Evidence

- Reproduction report:
  [`EXP-S6-MILESTONE-REPRO-20260927`](../../../experiments/step6/EXP-S6-MILESTONE-REPRO-20260927/REPORT.md)
- Raw build, programmer, dashboard, 300-second lock, same-PPS, trigger, and
  re-arm logs are retained in that experiment's `raw/` directory.
