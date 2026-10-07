# Main-root fresh backtrack: TIME_VALID300s PASS

**PASS_TIME_VALID_300S on both boards**, from a new main-root firmware build,
full FPGA compile and Slave-to-Master programming cycle. This is not reuse of
an older SOF or two reads of one previous boot.

Cycle: 2026-10-03T21:41:43+08:00 through22:12:10+08:00.
Actual source/compile checkout: `00b2342b22c8de000b08be4f4fc9ac1eb44f215e`.
Working root: `/home/b10504072/04_WR`; branch `feat/file_cleanup`.

## Change and meaning

The preceding unchanged-image trial failed on Slave with434/1192 invalid rows.
For the user's revised TIME_VALID-only target,12 historical production files
were restored to snapshot `0bb02c6f91dd4c7a578e1b8cb02a553ce9ce9787`.
All3110 original production inputs match; seven later diagnostic files remain
preserved but unlinked/unreferenced. Native/source tests and both firmware MIF
hashes independently validate the restored candidate.

Master bootstrap2048/reverse1/account64; Slave Main Kp300/Ki1, frequency
threshold20, full physical-step admission16; WR acquisition/2 and tracking/12.
No new gain sweep, guessed calibration, PHY/reset/timeout/SDC change or power
cycle. Frozen milestones and the protected archive were unchanged in this run.

IMPORTANT: historical WR validity semantics were restored. Numerical servo
entry/fallback thresholds60/120ps remain, but fine-phase fallback does not
clear TIME_VALID on every excursion. No host/observer forces the valid bit.
This PASS is **not strict-offset retention or proof of120ps accuracy**.

## Verification and actual products

Laptop12 offline/source/analyzer tests passed. Pain reran those12 tests and the
intact actual-controller C harness:22 cases, undefined-behaviour sanitizer,
normal acquisition rather than a forced entry. Both fresh MIFs match the
historically qualified bytes. The pinned firmware version string is reproducible
build metadata, not a false assertion that today's compile used the old commit.

| Board | MIF SHA256 | Actual new programmed SOF SHA256 |
|---|---|---|
| Master1-11.1 | `18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea` | `33e58bf47e7e944a30d90cb791eba0416213ad9838b073642e44b1057ea42134` |
| Slave1-11.2 | `91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379` | `fa5e4d2ce52e3cbbdf65ceaa14a34b0360d0e2af47bfb3fdd4385893b3e99c6f` |

Both full compiles succeeded, actual SOFs exist in `output/`, and both
programmers succeeded with0 errors/0 warnings and device ID0x02E660DD.
Master programming ended21:59:59+08:00. Both timing_closed=NO, recorded but
not used as a gate. Pre-change products are recoverably retained under
`raw/prechange-output/`; they are not promoted or mixed with qualified outputs.

Existing four-step scripts ran build_current → compile_current →
program_current → one-shot dashboard, followed by verify_time_valid_300s.
The initial Slave WAITING and all readiness polls are retained; only the later
complete valid window qualifies. Readiness bound600s, not1800s, for this trial.

## Complete sampled windows

| Board | TIME_VALID rows | Invalid | Sample span | Max gap | DONE elapsed |
|---|---:|---:|---:|---:|---:|
| Master1-11.1 |1191/1191|0|302747ms|257ms|303003ms|
| Slave1-11.2 |1190/1190|0|302799ms|257ms|303053ms|

Capture complete, board identities/index sequences/DONE counts valid, no
capture errors. PPS/snapshot/link diagnostics were also valid in every row;
live time progressed monotonically. These are diagnostic observations, not
additional acceptance gates. Board windows are sequential, requested250ms
sampling; not one simultaneous300s interval or per-clock continuity proof.

Raw `raw/observe/20261003T140009Z-current-time-valid-303s.log` SHA256:
`d023f54d66d60bb52ac66289673a87dff91085db4430ab66b9092cc86c581883`.
Result `analysis/20261003T140009Z-current-time-valid-300s.json` SHA256:
`70cab6aff964d87c134fd3fc292dbe480ffb2a9277c795ef76fe59e27eb50d67`.
Production manifest `output/SOURCE_SHA256SUMS` SHA256:
`418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a`.

All91 returned build/output/evidence files match the Pain transfer manifest.
Laptop independently reran the unchanged analyzer and obtained the same PASS.
Final dashboard also has both TIME_VALID/PPS_VALID1. Slave's pointwise CKO
was-227ps in WAIT_OFFSET_STABLE with all five lock flags1: explicitly shows
why this bit-only PASS must not be advertised as strict-offset convergence.

## Next authorized action

The user requested replacement of the single canonical Step6 package with
this successful main-root version, then a NEW independent milestone-source
build/compile/program/300s capture. That stronger reproduction is pending and
must have its own report; copying this PASS alone cannot establish it.
