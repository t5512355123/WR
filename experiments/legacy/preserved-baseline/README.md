# Preserved baseline blobs

This directory contains 184 exact Git-blob copies from baseline commit
`62182a94b437a7b0b77630f99ec50f788bc8ab7b`: 146 items initially lacking an
exact retained copy or verified archive mapping, plus 38 exact pre-migration
snapshots for relocated files whose content was updated during the move.

Files are named by their baseline Git blob ID plus the original basename to
avoid overly long workstation paths. `MANIFEST.tsv` maps every original path
to its retained copy and records the baseline blob ID, byte count, and
SHA-256. The copies are byte-for-byte preserved; their presence does not claim
that their historical content is current or needed by the active build. The
final per-file audit reports `UNEXPLAINED=0`.

The per-file audit and the script that generated it are in
[`experiments/repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/`](../../repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/).
