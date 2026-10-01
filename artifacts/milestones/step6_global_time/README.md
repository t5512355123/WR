# Step 6 — Global Time and dual-board scheduled digital trigger

**Revised 2026-10-01 acceptance: PENDING a 300-second Slave `TIME_VALID` capture.**
The frozen Step 6 source was independently rebuilt and programmed. Historical
hardware evidence established valid Global Time on both boards, five matching
common PPS labels, and two repeated dual-board scheduled digital triggers at
matching TAI/cycle labels.

The current acceptance requires the Slave's PPS-latched snapshot and exported
status to report `TIME_VALID=1` throughout a sampled 300-second window, using
stable, valid snapshots and advancing TAI/cycle data. Phase offset,
`PPS_VALID`, Step 1/link, Step 5 locks, and timing closure are not gates for
this revised target. The pointwise phase-offset gate below is retained as
historical evidence under the previous criterion, not as the current Step 6
acceptance.

## Acceptance evidence

| Gate | Result |
|---|---|
| Revised Slave TIME_VALID hold | PENDING: the 300-second sampled `TIME_VALID=1` capture in `EXP-S6-TIME-VALID-STABLE-300S-20261001` has not yet been run. This is the current acceptance gate. |
| Step 5 lock regression on Slave | PASS: 301/301 accepted samples; Helper, Main frequency, Main phase, Main lock, and PSTAT were locked in all 301 samples. |
| Global Time on both boards | PASS: valid/stable snapshots with `TIME_VALID=1` and `PPS_VALID=1`. |
| Historical dashboard phase gate (superseded) | PASS under the previous criterion: 958/958 rows had the complete Step 1 gate, valid/stable Global Time, and all five locks; rows #91 and #92 were consecutive samples 296 ms apart and each measured +59 ps with matching TAI/cycles and UCNT. |
| Same-PPS agreement | PASS: five common TAI labels matched exactly; maximum difference was 0 cycles (0 ns). |
| First scheduled digital trigger | PASS: Master and Slave each fired once at TAI 3094, cycle 62,500,000; measured digital label difference 0 cycles (0 ns). |
| Re-arm repeatability | PASS: both fired again at TAI 3679, cycle 62,500,000; each fire counter reached 2; second measured digital label difference 0 cycles (0 ns). |
| Post-fire health | PASS: link, Global Time, and Slave lock signals remained valid; sampled reset/generation counters did not change in the captured post-fire windows. |
| 300-second continuous phase-offset stability | NOT ESTABLISHED: only 2/958 valid CKO samples were strictly inside ±60 ps; valid-read range was −4094 to +2533 ps. This is not a Step 6 pointwise functional requirement. |
| Physical SMA/output-edge skew | NOT EVALUATED: digital timestamp equality is not an oscilloscope measurement. |

The latest [dashboard-equivalent gate capture](../../../experiments/step6/EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930/REPORT.md)
completed one 300-second read-only Slave observation (300,062 ms, 958 rows).
All 958 rows had valid reads and diagnostic frames, valid/stable Global Time,
all dashboard Step 1 bits, and all five lock signals. The two qualifying rows
were both in `TRACK_PHASE`, each with CKO=+59 ps, TAI=30432,
cycles=123289344, and publication UCNT=`0000708D`. No reset-signature
change, timeout, or invalid row occurred. Qualifying frames were guarded and
joined by UCNT; their separately acquired registers are not simultaneous and
do not prove servo causality.

A preceding one-shot dashboard observation reported −3779 ps and was correctly
not-qualified at that moment; the later pointwise samples demonstrate a
separate passing instant, not sustained tracking. The earlier
[UCNT-paired phase-context capture](../../../experiments/step6/EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/REPORT.md)
found four in-range joined rows at 27 ps but did not include the full dashboard
Step 1 bit set in its predicate; the latest capture closes that observability
gap. No production controls or frozen images were changed.

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

The historical pointwise phase criterion passed as recorded above, but it is
superseded by the revised 300-second TIME_VALID acceptance, which remains
pending. The phase-offset observations below remain diagnostic history; they
do not determine the revised result.

- The trigger comparison is based on the two boards' latched digital TAI/cycle
  labels. No oscilloscope measurement was made, so physical `SMA_CLKOUT` or
  output-pin skew remains **NOT EVALUATED**.
- The guarded `sfp params` cached-state query was attempted twice. Both
  attempts stopped before sending a firmware command because the shell-ready
  observer reported a non-idle persistent command stage. Therefore this
  experiment does not claim a direct CLI confirmation of the QSFP serial ID or
  calibration-database match; it does not invalidate the independently
  observed Global-Time/trigger gates.
- The superseded strict dashboard offset condition was pointwise: a valid integer CKO
  strictly inside +/-60 ps is accepted when the Step 1 gate, stable/valid time,
  and all five locks are high. The historical capture passed that prior
  gate in two consecutive sampled rows; it does not prove 300-second offset
  stability. Earlier exact-image and UCNT-paired captures remain diagnostic
  history and do not supersede the newer full Step 1-gated evidence. See the
  [dashboard-equivalent capture](../../../experiments/step6/EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930/REPORT.md),
  [exact-image phase capture](../../../experiments/step6/EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/REPORT.md),
  and [UCNT-paired phase-context capture](../../../experiments/step6/EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/REPORT.md).
- The runtime-trigger observers use target/ARM source writes only. They do not
  compile, program, reset, restart PTP, or change PPS configuration.
- Source audit of `vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c` confirms
  the software state thresholds: `WAIT_OFFSET_STABLE` enters `TRACK_PHASE`
  below 60 ps and returns to `SYNC_PHASE` after 10 missed polls;
  `TRACK_PHASE` returns to `SYNC_PHASE` above 120 ps and otherwise adjusts
  the phase setpoint by one quarter of the measured offset. This describes the
  control flow but does not explain the measured CKO transitions or prove
  causality. A source audit also established that these WDIAGS fields are
  republished as a software cache every 100 ms and `DATA_VALID` is cleared
  during refresh. The follow-on UCNT-paired capture used two separate
  DATA_VALID/epoch-guarded frames and joined only matching published UCNT
  values; 855/958 rows qualified. This improves frame validity but does not
  make the reads simultaneous or prove control causality. See
  [`EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930`](../../../experiments/step6/EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/REPORT.md).

## Evidence

- Dashboard-equivalent pointwise phase-gate capture:
  [`EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930`](../../../experiments/step6/EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930/REPORT.md)
  [`EXP-S6-MILESTONE-REPRO-20260927`](../../../experiments/step6/EXP-S6-MILESTONE-REPRO-20260927/REPORT.md)
- Exact-image strict-offset re-observation:
  [`EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929`](../../../experiments/step6/EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/REPORT.md)
- High-rate servo-transition correlation:
  [`EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929`](../../../experiments/step6/EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/REPORT.md)
- Raw build, programmer, dashboard, 300-second lock, same-PPS, trigger, and
  re-arm logs are retained in that experiment's `raw/` directory.
