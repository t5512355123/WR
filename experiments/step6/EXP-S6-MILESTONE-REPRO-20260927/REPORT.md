# EXP-S6-MILESTONE-REPRO-20260927 — interim report

## Verdict

```text
STEP6_MILESTONE = NOT_PASS
BUILD_MASTER = PASS
BUILD_SLAVE = PASS
PROGRAM_SLAVE = PASS
PROGRAM_MASTER = PASS
DASHBOARD_AFTER_PROGRAM = NOT_RUN
STEP5_DIRECT_LOCKS_300S = NOT_RUN
STEP6A_GLOBAL_TIME = NOT_RUN
STEP6A_SAME_PPS = NOT_RUN
STEP6B_DIGITAL_TRIGGER = NOT_RUN
STEP6_PHYSICAL_OUTPUT_EDGE_SKEW = NOT_EVALUATED
```

This is an interim record. Build and programming succeeded, but no post-program
runtime result has been collected; therefore neither Step 5 regression nor
Step 6 acceptance is established.

## Provenance and independent build

- Source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Repository commit checked out on Pain: `eedd3664c3ba7cfdddfed86de346e828ce32aca9`.
- Frozen source used directly: `artifacts/milestones/step6_global_time/source/`.
- Quartus: Prime Standard Edition 17.0.0 Build 595.
- Master firmware and Quartus clean compile: PASS.
- Slave firmware and Quartus clean compile: PASS.
- `TIMING_CLOSED=NO` for both boards. Timing closure is recorded but is not a
  functional Step 6 acceptance gate.

| Board | QSF SHA-256 | SDC SHA-256 | MIF SHA-256 | Rebuilt SOF SHA-256 |
|---|---|---|---|---|
| Master | `fc2f861ad6cf3a2f660ac66184fe054415515ab4006e578542ddce59ab026530` | `083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d` | `7620b1cab5f645a393409ecc0636332680bba78dc037aa2ef5629c562e819e39` | `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901` |
| Slave | `d074d47954f13d539d5477615a8a03752622b2b115dfa6684bc51169a3d7275d` | `083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d` | `3cf6affaf4cb4b1353e65a045dee3b6b3dccb2424bb338fac650afc77b0b4558` | `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450` |

Full build logs, firmware artifacts, reports, and copied SOFs were saved in the
Pain worktree under this experiment's `raw/build/` directory. They still need
to be synchronized to the Laptop repository and checksum-verified.

## Programming

- Slave `DE5 [1-11.2]`: configuration succeeded; one device configured; 0
  errors and 0 warnings.
- Master `DE5 [1-11.1]`: configuration succeeded; one device configured; 0
  errors and 0 warnings.
- Programming order was Slave then Master, using the SOFs built from the
  frozen source above.
- Complete Programmer logs were saved on Pain under this experiment's
  `raw/program/` directory and still need synchronization to Laptop.

## Runtime attempt and current boundary

The first dashboard invocation used direct execution of the shell script and
stopped before launching Quartus because the transferred script lacks its
executable bit (`Permission denied`). No JTAG/Wishbone observation was made by
that failed invocation. The correct invocation is
`bash scripts/monitor/step1_6_dashboard.sh`; no source permission or functional
change is needed.

The Pain SSH connection then closed, and a reconnect attempt to
`140.112.48.154:22` timed out. Thus the programmed-board runtime state and the
QSFP calibration parser's effect remain unverified. The build and programmer
logs are retained on Pain but have not yet been copied to this report's local
`raw/` folders.

## Next action

When Pain is reachable, continue on the same programmed image without
reprogramming: capture a read-only dashboard with a bounded Global-Time wait,
inspect the cached QSFP calibration result, then run the full direct-lock,
same-PPS, and scheduled-trigger gates. Save all raw outputs locally, checksum
them, update this report with measured results, and only then decide whether
the formal Step 6 milestone can be frozen.
