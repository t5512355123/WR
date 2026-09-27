# EXP-S6-MILESTONE-REPRO-20260927 — final report

## Verdict

```text
STEP5_SLAVE_LOCK_REGRESSION_300S = PASS
STEP6A_GLOBAL_TIME_VALID_BOTH_BOARDS = PASS
STEP6A_SAME_PPS_LABELS = PASS (5/5 exact matches; 0-cycle maximum delta)
STEP6B_FIRST_DUAL_BOARD_DIGITAL_TRIGGER = PASS (0-cycle delta)
STEP6B_REARM_REPEATABILITY = PASS (0-cycle second-trigger delta)
STEP6_FUNCTIONAL_MILESTONE = PASS
SFP_CACHED_CALIBRATION_CLI_CHECK = INCONCLUSIVE (guarded; no command sent)
PHYSICAL_SMA_OUTPUT_EDGE_SKEW = NOT_EVALUATED
TIMING_CLOSED = NO (not a Step 6 functional gate)
```

Step 6 functional PASS is based on the independently rebuilt/programmed image,
valid Global Time on both boards, five exact common PPS labels, two successful
dual-board scheduled digital firings, and healthy post-fire state. The separate
cached `sfp params` diagnostic was not obtained because its shell-idle guard
failed twice. That sub-check is explicitly left inconclusive; no unsafe command
was sent and no calibration database match is claimed.

## Source and build provenance

- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Dashboard/source overlay commit: `3b3a8ec52668d0c60550451ef1780539f7c93fd7`.
- Pain checkout used for independent build/program: `eedd3664c3ba7cfdddfed86de346e828ce32aca9`.
- Frozen source directory: `artifacts/milestones/step6_global_time/source/`.
- Quartus Prime Standard Edition 17.0.0 Build 595; firmware toolchain and
  complete build outputs are recorded under `raw/build/`.
- Master build: PASS. Slave build: PASS. Both Fitter runs completed; timing
  closure remains NO and is not a Step 6 acceptance condition.

| Board | QSF SHA-256 | SDC SHA-256 | MIF SHA-256 | Rebuilt SOF SHA-256 |
|---|---|---|---|---|
| Master | `fc2f861ad6cf3a2f660ac66184fe054415515ab4006e578542ddce59ab026530` | `083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d` | `7620b1cab5f645a393409ecc0636332680bba78dc037aa2ef5629c562e819e39` | `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901` |
| Slave | `d074d47954f13d539d5477615a8a03752622b2b115dfa6684bc51169a3d7275d` | `083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d` | `3cf6affaf4cb4b1353e65a045dee3b6b3dccb2424bb338fac650afc77b0b4558` | `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450` |

The milestone `master.sof` and `slave.sof` are byte-identical copies of these
newly rebuilt files. Programming succeeded in the required order: Slave first
on `DE5 [1-11.2]`, then Master on `DE5 [1-11.1]`; each programmer run
configured one device with zero errors and warnings. Full logs are in
`raw/program/`.

## Post-program dashboard

The read-only Step 1–6 dashboard showed both boards with SI configuration,
CPU reset released, WR link and endpoint link up, valid PPS snapshots, and
`TIME_VALID=1` / `PPS_VALID=1`. The Slave reported Helper, Main frequency,
Main phase, Main lock, and PSTAT lock. The one-shot dashboard's Step 5
stability label was not used as the 300-second gate; the separate time series
below supplies that evidence. See
`raw/observe/dashboard_after_program_wait120.log`.

## Step 5 300-second regression

Observer configuration was 301 samples per board with a requested 1000 ms
inter-sample delay. The boards were sampled sequentially. The Slave section
contains:

```text
accepted samples                 301 / 301
STEP5_SAMPLE_VALID=1             301 / 301
LOCKED_SAMPLE                    301 / 301
UNLOCKED_SAMPLE                    0
series result                    STABLE_LOCK_CANDIDATE
```

Every accepted Slave row's lock detector required Helper locked, Main enabled
and locked, Main frequency locked, Main phase locked, and PSTAT locked. The
log's configured cadence plus 301 samples spans at least 300 requested
one-second intervals; the complete serial two-board capture ran from
06:43:27 to 06:59:27. Master is intentionally not expected to run the Slave
SoftPLL and is `NEVER_LOCKED` in this Slave-lock observer. Raw evidence:
`raw/observe/step5_300s_timeseries.log`.

## Step 6A — Global Time and same-PPS agreement

- Both boards produced valid, stable snapshots with `TIME_VALID=1` and
  `PPS_VALID=1`.
- The capture contained five common TAI labels; all five cycle values matched
  exactly. `MAX_ABS_DELTA_TICKS=0`, `MISMATCH_LABELS=0`.
- Reset/generation evidence was unchanged during the capture:
  `RESET_CHANGED=0`, boot generation 1, CPU reset count 1, WR-core reset count
  1, and SI configuration-drop count 1 on both boards.
- Capture result: `PASS_SAME_PPS_GLOBAL_TIME_CONSISTENCY`.

Raw evidence: `raw/observe/same_pps_after_program.log`.

## Step 6B — dual-board scheduled digital trigger

The live-session mode performed no compile, programming, reset, PTP restart,
or power cycle. After a clean pre-write gate, it wrote the common target and
ARM sources on both boards and then observed the latched result:

| Trial | Common target | Master/Slave firings | Both actual TAI/cycles | Digital delta |
|---|---|---:|---|---:|
| First fire | TAI 3094, cycle 62,500,000 | 1 each | Exact match | 0 ticks / 0 ns |
| Re-arm repeat | TAI 3679, cycle 62,500,000 | 2 each cumulatively | Exact match | 0 ticks / 0 ns |

Both pre-write gates, target readback, dual-arm latch, common-time coherence,
and post-fire health passed. Each post-fire capture contained three samples;
link, Global Time, and Slave locks remained valid and reset/generation
counters did not change. The second observer used the actual prior target
TAI (`3094`) for its precondition instead of a stale hard-coded value.

Raw evidence: `raw/observe/step6b_live_trigger.log` and
`raw/observe/step6b_rearm_repeatability.log`.

## SFP diagnostic boundary

The guarded cached-state command `sfp params` was attempted twice. Each run
reported `COMMAND_STAGE_NOT_IDLE` and stopped without sending a firmware
command. This is an inconclusive diagnostic observation, not evidence that
the parser or calibration lookup failed. It also is not evidence of a match;
serial ID and calibration database match remain unverified by the CLI.
Logs: `raw/observe/sfp_params_readonly.log` and
`raw/observe/sfp_params_readonly_retry.log`.

## Limitations

- The trigger is verified through the boards' latched digital TAI/cycle
  signals. There is no oscilloscope evidence for physical SMA/output-pin skew;
  that remains `NOT_EVALUATED`.
- Step 6 does not claim timing closure.
- Step 5 series samples were taken sequentially by board, not atomically
  across Master and Slave. Same-PPS correlation is a separate capture.

## Reproduction artifacts

- Frozen milestone: `artifacts/milestones/step6_global_time/`.
- Experiment plan: `PLAN.md`.
- Raw build/program/observation files: `raw/`.
- Machine-readable acceptance evidence is summarized in
  `analysis/acceptance-gates.tsv`. `SHA256SUMS` covers the plan, report,
  analysis, and raw files; regenerate or verify it with
  `analysis/write_sha256sums.py`.
