# Final repository verification addendum — 2026-09-27

This addendum supersedes the earlier summary counts in `REPORT.md` and the
earlier `analysis/preservation-audit.tsv` snapshot. It records the final
verification after removing the redundant build placeholder and promoting the
current Step 6 research chain.

## Preservation and Step 6 promotion

- Pre-restructure baseline: `62182a94b437a7b0b77630f99ec50f788bc8ab7b`.
- Final preservation result: 7,428 exact retained/moved blobs, 4 intentionally
  removed non-evidence entries, and `UNEXPLAINED=0`.
- Final row-level evidence: [`analysis/preservation-audit-final.tsv`](analysis/preservation-audit-final.tsv).
- The zero-byte `build/.gitkeep` was intentionally removed after confirming
  both firmware build scripts create `$ROOT/build`; generated build output is
  still ignored by `.gitignore`.
- Step 6 promotion compared task-start commit
  `c55e32a3b477a6c3bced43a346fdca8e5bece4b0` with the current tree. All 467
  original Step 6 files are accounted for: 466 exact moves and one
  link-adjusted file with its original blob retained in the baseline archive;
  no unique Step 6 evidence is missing.
- Promotion rows and checker: [`analysis/step6-promotion-audit.tsv`](analysis/step6-promotion-audit.tsv),
  [`analysis/audit_step6_promotion.py`](analysis/audit_step6_promotion.py).

## Functional and repository verification

- Step 6 is PASS: frozen source rebuilt on Pain, both rebuilt SOFs programmed,
  Step 5 Slave locks held across the 300-second series, five common PPS labels
  matched, and both scheduled dual-board digital triggers plus the re-arm run
  matched exactly. See the [reproduction report](../../step6/EXP-S6-MILESTONE-REPRO-20260927/REPORT.md).
- `python -m unittest discover -s scripts/tests`: 84 tests passed. The
  Windows host needed Git for Windows `bin` added to `PATH` so the dashboard's
  Bash-backed integration tests could run.
- Markdown link audit: 780 project Markdown files and 436 local links checked;
  zero broken local links. Vendored Markdown and exact baseline snapshots were
  excluded by the checker’s tested policy.
- The Step 6 experiment has its own `analysis/acceptance-gates.tsv` and
  44-entry `SHA256SUMS`, verified by
  `analysis/write_sha256sums.py --check`.

## Explicit non-claims

- Physical SMA/output-edge skew remains `NOT_EVALUATED`; no oscilloscope
  measurement was taken.
- The guarded `sfp params` cached-calibration CLI query remains inconclusive;
  its idle gate stopped both attempts before sending a command.
- Timing closure remains `NO` and is not a functional Step 5 or Step 6 gate.
