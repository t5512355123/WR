# EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924 — Artifact deduplication

Date: 2026-09-24
Branch / baseline source commit: `feat/file_cleanup` / `61fa7a2b`

## Objective and hypothesis

Reduce `artifacts/` to the milestone-only contract while preserving every
unique historical evidence file in `experiments/legacy/`. Exact copies and
transfer archives may be removed only after content-level verification.

## Baseline and fixed conditions

- Laptop checkout on `feat/file_cleanup`; remote branch was at `61fa7a2b`.
- Do not alter milestone source, experiment raw content, or hardware state.
- Keep the two Step1 milestone SOFs and verify them against their published
  SHA-256 values.

## Single variable under test

Repository evidence placement and duplicate elimination only. No RTL,
firmware, build configuration, or FPGA programming was changed.

## Procedure

1. Compare tracked `artifacts/` files against experiment Git blobs.
2. Hash every ignored/untracked artifact and compare against retained evidence.
3. For each transfer archive, hash every file member against its matching
   experiment directory; validate available sidecars against their archive.
4. Move unique files into their corresponding `experiments/legacy/` record.
5. Remove only copies whose SHA-256 matched an already retained file; retain
   the audit tables and a per-file pruning script that fails closed.

## Acceptance criteria and stop conditions

- `artifacts/` contains no regular file except `README.md` and files below
  `artifacts/milestones/`.
- No unique evidence is removed; exact file paths and SHA-256 values remain
  recorded in `analysis/artifact-migration-audit.tsv` and
  `analysis/untracked-artifact-audit.tsv`.
- Step1 Master/Slave milestone SOFs remain in the index and match the
  milestone manifest.
- Stop immediately on any missing retained copy or hash mismatch.
