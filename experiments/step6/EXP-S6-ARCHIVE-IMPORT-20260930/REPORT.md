# EXP-S6-ARCHIVE-IMPORT-20260930 — Archive reconciliation

## Result

```text
ARCHIVE_ACCESS          = READ_ONLY
ARCHIVED_TEXT_SNAPSHOT  = 80 files / 4,267,763 bytes
ARCHIVE_RAW_RECONCILE   = NO DIFFERENCES FOUND
CANONICAL_OVERWRITES    = 0
GENERATED_BUILD_OUTPUTS = NOT IMPORTED
```

The archive was used only as a source for inspection and copying. No file in
`/home/b10504072/04_WR_archive_step6_pass/` was changed, renamed, or removed.
The snapshot in `archive_snapshot/experiments/` preserves 78 archive text
records plus two older Step 6 files that had since been superseded in the
active checkout. The copies were placed under this import experiment so the
older versions remain available without replacing current canonical documents.

## Reconciliation

- The archive's `experiments/**/raw/` trees had no missing or checksum-different
  files relative to the active repository at inspection time; existing raw
  evidence was already present in the canonical experiment folders.
- The archived Step 6 `README.md` and
  `EXP-S6-MILESTONE-REPRO-20260926/analysis/verify_step6_source.py` differ from
  newer active versions. Both archive versions are preserved under
  `archive_snapshot/`; neither replaced the active version.
- The other 78 selected text records (including experiment build logs,
  recorded hashes, and vendor text documentation) were checksum-staged from
  the archive and copied into the snapshot tree.
- A checksum dry-run identified 12,995 archive/active differences overall,
  predominantly generated build directories, Quartus databases, and output
  products. Those generated trees were not imported: they are not canonical
  experiment records, would duplicate reproducible build products, and are
  not required to preserve the raw measurements or source/build logs.
- The active Step 6 README continues to distinguish its historical digital
  trigger pass from the stricter current phase-offset gate. The historical
  archived README is retained only as a provenance snapshot.

## Verification

- Snapshot files: 80.
- Snapshot size: 4,267,763 bytes.
- Archived Step 6 README SHA-256:
  `d307e9a2b3a86b071ecb8a97222f87150018b411d0b3f6e2330db55607effdaf`.
- Archived verifier SHA-256:
  `b32ba9b7e0cd259ed89c655080bfac644e66214c895f44801d9de63952c8aac9`.
- Source archive remained outside the write target throughout the operation.

This import does not change milestone status or count as new hardware
validation. The latest Step 6 result remains `NOT ESTABLISHED` under the
strict `<60 ps` phase-offset criterion.
