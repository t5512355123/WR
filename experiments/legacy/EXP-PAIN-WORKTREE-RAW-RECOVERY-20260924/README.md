# Pain worktree evidence recovery — 2026-09-24

This directory indexes previously untracked experiment evidence recovered
from Pain worktrees before those worktrees are cleaned up. It is a provenance
archive, not a new Step PASS verdict. The current Step5 and Step6 milestone
verdicts remain in their dedicated milestone reports.

## Recovered evidence

```text
RAW_FILES_RECOVERED = 53
RAW_BYTES_RECOVERED = 6,182,890
DISTINCT_RAW_CONTENTS = 53
ADDITIONAL_SOURCE_PATCH = 1
ALREADY_VERSIONED_DUPLICATES_SKIPPED = 122
```

Every recovered file was copied byte-for-byte and its source/destination Git
blob IDs were checked. `MANIFEST.tsv` records the original Pain worktree,
source commit, source kind (`file` or `git-diff`), source path/operation,
destination path, SHA-256, and byte count.
The skipped files had exact content matches already present elsewhere in the
fetched `feat/file_cleanup` tree; no unique contents were skipped.

Step6 dashboard experiments that had been stored under the Step5 directory
were placed under `docs/experiments/exp-step6-global-time/`. The manifest
preserves their original paths. Earlier `.codex-preserved-*` captures were
consolidated under `EXP-S6-LEGACY-CAPTURE-ARCHIVE-20260924/` while retaining
their original capture-directory names.

The additional Main-trace publication-throttle patch is archived at
`docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-88604A5-MAIN-TRACE-2S-PUBLICATION-MAIN-FREQUENCY-PRELOCK-OBSERVABILITY-600S-20260902/maintrace-publish-throttle-worktree.patch`.
It is the output of `git diff --binary -- vendor/wrpc-sw/lib/task-diags.c`,
an unapplied worktree diff based on commit
`88604a5ca174fd3b36b0a8eb435ec1773dd061a3`; it is retained for provenance
and is not asserted to be part of the current firmware image.

No SOF or MIF is included in this recovery archive. The separate Step1,
Step4B, Step5, and Step6 milestone-image inventories determine which
programming images are retained.
