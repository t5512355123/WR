# EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001

## Objective

Reproduce 300 seconds of continuously sampled exported `STATUS_TIME_VALID=1`
independently on Master `1-11.1` and Slave `1-11.2`.

## What the historical records show

The previous 300-second observers sampled only the Slave. A complete audit of
all saved 300-second Step 6 captures found several candidates where every
sampled status bit stayed high, but the last sample arrived just before the
required first-to-last 300,000-ms span:

| Candidate | Valid samples | Sample span | Largest gap | Board |
|---|---:|---:|---:|---|
| Frozen dashboard-equivalent image | 958/958 | 299,755 ms | 410 ms | Slave |
| Full acquisition + /12 tracking | 957/957 | 299,931 ms | 410 ms | Slave |
| Quarter acquisition + /4 tracking | 957/957 | 299,984 ms | 409 ms | Slave |
| /2 acquisition + /12 tracking | 959/959 | 299,998 ms | 411 ms | Slave |
| Full acquisition + /12 tracking, 4x fallback | 953/953 | 299,727 ms | 411 ms | Slave |
| Canonical frozen baseline | 0/1,186 | 301,860 ms | 257 ms | Slave |

No saved 300-second raw capture covers Master; therefore none proves the
current two-board criterion. The /2 + /12 candidate is the best starting point:
it has 959/959 valid Slave rows and missed the span criterion by only 2 ms.
The prior observer requested exactly 300,000 ms, but its last sample occurred
at 299,998 ms even though its completion marker was at 300,403 ms. This run
keeps the same candidate source and firmware MIFs and requests 303,000 ms per
board. A fresh Quartus fit may produce a different SOF hash; such an output is
recorded and evaluated as a fresh same-source candidate, never described as a
byte-identical historical image. No PI, servo, timeout, threshold, reset, PHY,
RTL, SDB, or timing-constraint change is introduced.

## Exact candidate provenance

- Branch: `feat/file_cleanup`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Historical FPGA/firmware build commit: `4c1adf73ab762506939163d467fb8c6b35bca9b4`.
  The firmware embeds `__GIT_VER__` in its MIF even with
  `CONFIG_DETERMINISTIC_BINARY=y`; therefore the same source patch built at a
  later repository commit does not recreate the proven MIFs. Build in an
  isolated temporary worktree at this exact commit.
- Reuse, unchanged, the historical patch at
  `experiments/step6/EXP-S6-WRH-SERVO-ACQUIRE-HALF-TRACK-TWELFTH-20260930/candidate.patch`.
- Candidate source behavior: `WRH_SYNC_PHASE` acquisition is `offset_ps / 2`;
  `WRH_TRACK_PHASE` correction is `offset_ps / 12`. All other candidate
  source, thresholds, retry/fallback behavior, PPS/TAI handling, RTL, SDB,
  reset behavior, PHY configuration, and timing constraints remain frozen.
- Expected Slave SOF SHA-256:
  `dd5d2e72d6fcde92ace62cf51cfd7fc333c5af1d8d8dd4ebfdc8437b3bba701b`.
- Expected Master SOF SHA-256:
  `2beddef2b481c96d6b94bf195fc3ea3cd87513bc776b6884cc775ee8d08f763b`.
- Historical board-project hashes: Master QSF
  `fc2f861ad6cf3a2f660ac66184fe054415515ab4006e578542ddce59ab026530`, Slave
  QSF `d074d47954f13d539d5477615a8a03752622b2b115dfa6684bc51169a3d7275d`, and
  shared SDC `083b6dce769023afa8d8c425b6ea56f6f0c8b2bb315396235b050c8cc179715d`.
- The historical SOF hashes are provenance references, not a hard equality
  gate for a fresh Quartus run. The exact historical binaries are not stored
  with the repository records. A fresh image may be programmed only after the
  source patch, source origin, firmware MIFs, QSF/SDC, Quartus version, and both
  full compilations pass their exact checks; record each newly generated SOF
  hash and call it a fresh same-source build, not a byte-identical historical
  image.
- Expected Slave firmware MIF SHA-256:
  `d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916`.
- Expected Master firmware MIF SHA-256:
  `07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6`.
- Historical SOF hashes above document the previously exercised binaries but
  are not a hard equality gate: those binaries are not present in the saved
  repository records. Program the freshly built outputs only after the source,
  patch, MIF, QSF/SDC, Quartus version, and full-compilation checks pass.
  Record the actual fresh SOF hashes and program Slave first, then Master.

## Laptop -> GitHub -> Pain workflow

1. On Laptop, run the historical patch-contract test, this experiment's
   offline safety tests, the 300-second analyzer tests, and `git diff --check`.
   Push this plan, scripts, report stub, and corrected active-experiment
   references to `origin/feat/file_cleanup`.
2. On Pain, fast-forward `/home/b10504072/04_WR` to that exact commit. Do not
   access `/home/b10504072/04_WR_archive_step6_pass/`. Preserve all existing
   untracked user data.
3. Compile only, using the exact pulled commit:

   The build command accepts `scripts/build_candidate.sh EXPECTED_CURRENT_COMMIT`.

   ```sh
   EXPECTED_COMMIT=$(git rev-parse HEAD)
   bash experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/scripts/build_candidate.sh "$EXPECTED_COMMIT"
   ```

   This verifies the checkout, creates an isolated temporary worktree at the
   pinned historical build commit above, verifies the frozen source and
   canonical artifact manifests, applies the existing patch, builds both
   images, and validates the historical MIF, QSF, SDC, Quartus-version, and
   full-compilation identities. It then copies the verified SOFs out of the
   temporary worktree and leaves them in the ignored, persistent folder:

   ```text
   experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/output/BUILD_RUN_TAG/DE5a_wr_slave_jtag.sof
   experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/output/BUILD_RUN_TAG/DE5a_wr_master_jtag.sof
   ```

   The script prints `S6TV_BUILD_COMPLETE` only after the temporary worktree is
   removed and both retained files still exist, are non-empty, and match the
   generated build-info hashes. It does not query JTAG cables, request sudo,
   or program either board. The printed `run_tag` is passed unchanged to the
   next phase. A failed or incomplete compile cannot be programmed. The SOFs
   are ignored local build outputs: they remain on Pain under `output/` and
   are not uploaded to GitHub with the source commit.
4. Program only the retained SOFs, using the same checkout commit and build
   run tag:

   The programmer command accepts `scripts/program_candidate.sh EXPECTED_CURRENT_COMMIT BUILD_RUN_TAG`.

   ```sh
   bash experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/scripts/program_candidate.sh "$EXPECTED_COMMIT" BUILD_RUN_TAG
   ```

   This checks both output files and their SHA-256/build metadata before any
   programming, verifies both cable identities, then programs Slave followed
   by Master. The SOFs remain in `output/BUILD_RUN_TAG/`; the program log names
   the exact files consumed. Do not rebuild between these two phases unless
   you intend to use the newly printed build run tag.
5. Start the read-only live dashboard only after programming completes:

   ```sh
   INTERVAL_SECONDS=10 OBS_GAP_MS=2000 bash scripts/monitor/step1_6_dashboard.sh
   ```

   The dashboard displays the current state. Stop it with Ctrl+C before
   starting the separate long JTAG capture; do not run two JTAG readers at
   once. The capture script polls both boards
   read-only until `STATUS_TIME_VALID=1` in every preflight sample for both
   boards during one poll, with a maximum readiness wait of 1,800 seconds.
   This is only a start gate; it does not replace the long capture.
6. The long observer is read-only and sequential by board:

   ```text
   scripts/jtag/read_step6_global_time_observability.tcl
   duration_ms = 303000
   sample_ms   = 250
   board_filter = empty (both visible DE5a boards)
   ```

   A 900-second process deadline covers both sequential board windows.
7. Copy the unmodified raw capture and build/program logs back to Laptop,
   verify SHA-256 values, run `scripts/analysis/step6_time_valid_300s.py`,
   update REPORT.md, then push the evidence and report to the same branch.

## Acceptance contract

`STEP6_TIME_VALID_300S_BOTH_BOARDS=PASS` only if the exact capture contains
both required board IDs and, independently for each board:

- at least 301 ordered samples;
- first-to-last sample span of at least 300,000 ms;
- the board completion marker covers at least 300,000 ms;
- every adjacent sample gap is positive and no greater than 1,000 ms; and
- every sampled `STATUS_TIME_VALID` value is exactly 1.

The capture must have no observer error, missing board, reset interruption, or
sequence mismatch. The two boards are sampled sequentially, not atomically.
Snapshot/PPS flags, TAI/cycle values, link/Step 1, Step 5 locks, phase offset,
and timing closure are diagnostics only. This proves sampled persistence of
the exported bit; it does not claim cycle-by-cycle continuity between reads.

## Stop conditions

- Stop before patching/building if branch/commit or source/artifact manifests
  do not match, or another Quartus process is active.
- Stop before Quartus compilation if either firmware MIF hash differs from
  the historical expected hash. Stop before SOF retention if either
  source/QSF/SDC/tool identity differs, either compilation fails, or either
  generated SOF is absent. Stop before programming if either retained SOF is
  absent, empty, or fails its SHA-256/build-info check, or cable/process
  preflight fails. A newly generated SOF hash need not equal the historical
  hash; record it and do not claim byte-identical image reproduction.
- Stop if either programming log does not identify one successfully configured
  DE5a device on the expected cable.
- Preserve all partial evidence and stop on reset interruption, read errors,
  timeout, board loss, or capture/analyzer errors. Do not label partial
  evidence a pass.
- If either board drops `STATUS_TIME_VALID`, classify the target
  `NOT_ESTABLISHED`; do not tune or program another candidate in this run.

## Independent repeat #2 — PASS, 2026-10-01

The second fresh build/program/capture used the same frozen `/2 acquisition +
/12 tracking` candidate and passed the acceptance contract on both boards.
Build run tag `20261001T112327Z`; capture run tag `20261001T114109Z`. The full
report records the exact SOF hashes and per-board metrics.

Across the two independent fresh build/program runs, every sampled
`STATUS_TIME_VALID` row passed for both boards for at least 300 seconds. This
supports reproducibility for the stated sampled-bit criterion; it is not a
cycle-by-cycle continuity measurement or a claim of indefinite stability.
No further controller tuning is justified by this target alone.

## Current operation (2026-10-02)

The successful source is now promoted to the repository root. The old
experiment-local build/program/capture entrypoints have been retired.
Use these four steps from the repository root:

1. `bash scripts/build/build_current.sh`
2. `bash scripts/build/compile_current.sh`
3. `bash scripts/program/program_current.sh`
4. `bash scripts/monitor/step1_6_dashboard.sh`

Stop the dashboard before the separate acceptance capture:
`bash scripts/monitor/verify_time_valid_300s.sh`.
The SOFs persist in `output/`; evidence goes in this experiment's raw/analysis
directories. The earlier procedure above is a historical record, not the
current operational workflow.
