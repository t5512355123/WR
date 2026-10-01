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
keeps the same candidate source and images and requests 303,000 ms per board.
No PI, servo, timeout, threshold, reset, PHY, RTL, SDB, or timing-constraint
change is introduced.

## Exact candidate provenance

- Branch: `feat/file_cleanup`.
- Frozen Step 6 source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
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
- Build and program only if both rebuilt SOF hashes exactly match those
  previously exercised artifacts. Program Slave first, then Master.

## Laptop -> GitHub -> Pain workflow

1. On Laptop, run the historical patch-contract test, this experiment's
   offline safety tests, the 300-second analyzer tests, and `git diff --check`.
   Push this plan, scripts, report stub, and corrected active-experiment
   references to `origin/feat/file_cleanup`.
2. On Pain, fast-forward `/home/b10504072/04_WR` to that exact commit. Do not
   access `/home/b10504072/04_WR_archive_step6_pass/`. Preserve all existing
   untracked user data.
3. Run the build/program script with the exact pulled commit. It verifies the
   frozen source manifest (3,219 entries), canonical Step 6 SOF manifest
   (4 entries), both JTAG cables, and no competing Quartus/JTAG process. It
   temporarily applies the existing patch, builds both images, verifies the
   historical SOF hashes, programs Slave then Master, restores the patch, and
   verifies both manifests again.
4. Do not run two JTAG readers at once. The capture script polls both boards
   read-only until `STATUS_TIME_VALID=1` in every preflight sample for both
   boards during one poll, with a maximum readiness wait of 1,800 seconds.
   This is only a start gate; it does not replace the long capture.
5. The long observer is read-only and sequential by board:

   ```text
   scripts/jtag/read_step6_global_time_observability.tcl
   duration_ms = 303000
   sample_ms   = 250
   board_filter = empty (both visible DE5a boards)
   ```

   A 900-second process deadline covers both sequential board windows.
6. Copy the unmodified raw capture and build/program logs back to Laptop,
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

- Stop before patching/building if branch/commit, source/artifact manifests,
  cable identities, or JTAG process preflight do not match.
- Stop before programming if either SOF hash differs from the historical
  expected hash or either compilation fails.
- Stop if either programming log does not identify one successfully configured
  DE5a device on the expected cable.
- Preserve all partial evidence and stop on reset interruption, read errors,
  timeout, board loss, or capture/analyzer errors. Do not label partial
  evidence a pass.
- If either board drops `STATUS_TIME_VALID`, classify the target
  `NOT_ESTABLISHED`; do not tune or program another candidate in this run.
