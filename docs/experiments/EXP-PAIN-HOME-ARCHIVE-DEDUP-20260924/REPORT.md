# EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924

## Scope and method

This archive pass inventories twelve specifically named home-level Pain
preservation directories against Git-tracked file contents at the clean
`feat/file_cleanup` checkout, then stages any unique non-build research
records into the corresponding experiment folders. Comparison uses Git blob
object IDs, so byte-identical files are recognized even when stored under a
different archive directory. No SOF or MIF was found in these twelve source
directories.

```text
SOURCE_ROOT=/home/b10504072
REFERENCE_BRANCH=feat/file_cleanup
REFERENCE_HEAD_BEFORE_THIS_REPORT=13b685c1d3ceaec654945e67ebd134f9287185b4
SOURCE_FILE_COUNT=281
EXACT_CONTENT_DUPLICATES_ALREADY_TRACKED=272
UNIQUE_FILES_RECOVERED=9
SOF_OR_MIF_IN_SCOPE=0
```

## Directory audit

| Pain directory | Files | Exact tracked duplicates | Unique |
| --- | ---: | ---: | ---: |
| `pain-evidence-archive` | 109 | 109 | 0 |
| `pain-preserve` | 33 | 33 | 0 |
| `pain-preserved` | 84 | 78 | 6 |
| `pain-preserved-step6-gt-revalidation-e45ec5e3` | 5 | 5 | 0 |
| `pain-preserved-step6-postmortem-6c5d4f26` | 5 | 5 | 0 |
| `pain-preserved-step6-ptp-restart-before-tail-pull-20260922` | 5 | 4 | 1 |
| `pain-preserved-step6-rebuild-observer-runtime-1951c40` | 15 | 15 | 0 |
| `pain-preserved-step6-tail-before-same-pps-pull-20260922-analysis` | 2 | 2 | 0 |
| `pain-preserved-step6-tail-before-same-pps-pull-20260922-raw` | 3 | 2 | 1 |
| `pain-preserved-step6-wr-fallback-9651ccc1` | 5 | 5 | 0 |
| `pain-preserved-step6b-before-pull-20260922` | 5 | 4 | 1 |
| `pain-preserved-step6b-timing-correction-before-pull-20260922` | 10 | 10 | 0 |
| **Total** | **281** | **272** | **9** |

## Recovered unique records

All nine files were copied from the Pain archive to the laptop workspace and
SHA-256 verified against their Pain sources. The supplemental captures retain
distinct names so they cannot silently overwrite canonical evidence.
The three raw Quartus observer logs are preserved byte-for-byte, including
fixed-width vendor-header trailing spaces; they were not normalized so their
source SHA-256 remains verifiable.

| Repository path | SHA-256 |
| --- | --- |
| `docs/experiments/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/sta/DE5a_wr_master_jtag.sta.summary` | `b7f579467bbe949eafa0dc1886ef87beeccb174d674846a154de1bc833b25160` |
| `docs/experiments/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/sta/DE5a_wr_slave_jtag.sta.summary` | `a9582025d5dfaf64d4def525e103c8de2e65b00c41ff70cc9c182a9d79fd9020` |
| `docs/experiments/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/fit/DE5a_wr_master_jtag.fit.summary` | `fd533c013940af8f4b696908731eb810b1520bea9b18aedab9a987d34d12893b` |
| `docs/experiments/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/fit/DE5a_wr_slave_jtag.fit.summary` | `d823d29ddb80ef79b6f1afd19a07b43fb2fa4fcc75e5f5be4dba6abf24d6dd45` |
| `docs/experiments/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/file-sha256.txt` | `48ff9a52b0e64a6d98b4b3c01966136eb25bc9479a69bb3a5c50c5af58a0d5cd` |
| `docs/experiments/exp-step5-softpll-lock/EXP-S5-FAST100C-SYSCLK625-HOLD-PATH-AUDIT-20260920/raw/pre-pull-raw-20260920/file-sha256.txt` | `55c244e59866e92fd85bb016ff36d3287497781351cc443f53165d9fbd342f11` |
| `docs/experiments/exp-step6-global-time/EXP-S6-SLAVE-PTP-RESTART-WR-EXTENSION-RECOVERY-20260922/raw/observe/ptp_restart_recovery_pre_pull.log` | `2eb570a979fef7b4d88e6338db24f815b296071281ba1378f1024f317dd2b5ca` |
| `docs/experiments/exp-step6-global-time/EXP-S6-GLOBAL-TIME-LATE-RECOVERY-TAIL-STABILITY-20260922/raw/observe/late_recovery_tail_pre_pull.log` | `7372cf01fce4da4685366dc519941165f5e17d395bca0fb7428ae7e06bef7b47` |
| `docs/experiments/exp-step6-global-time/EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922/raw/observe/same_pps_consistency_pre_pull.log` | `274b5068267c3c19afe411b9626dd431f76272be5496ce4e349374855dccb30e` |

## Cleanup status

The recovered records and this audit were pushed to GitHub and verified in
Pain's clean GitHub checkout at commit
`a1444f1e005501e93276604ec24e7250f08fd203` before cleanup. On 2026-09-24, all
twelve exact source directories in the table were revalidated and removed:
281 files total, with no symlinks, special files, SOF, or MIF. Their contents
remain recoverable from Git: 272 were exact duplicates already tracked at the
pre-archive baseline and the other nine are versioned at the paths above.

The active Pain checkout, `snap`, and `share` were not touched.

Milestone SOFs are outside this audit and must remain retained with their
matching hashes and provenance.

## Old `/04_WR` checkout untracked-file audit

Pain's primary checkout was still at `f847f4e74c5b16389c9848d4fe2592a9873a6b5c`
on `exp/step5-softpll-lock`. Its 505 untracked status entries consisted of
490 regular files and 15 registered nested-worktree directories. The 490
regular files were compared by exact Git blob identity against the
`feat/file_cleanup` tree; after the source archive above was added, every
file's contents are represented in the branch:

```text
EXACT_CONTENTS_ALREADY_TRACKED_AT_OTHER_PATHS = 468
  same relative path                             = 376
  alternate tracked path                        = 92
UNIQUE_FILE_COPIES_NOW_ARCHIVED                 = 22
DISTINCT_NEW_CONTENT_BLOBS                      = 7
NESTED_WORKTREE_DIRECTORIES_EXCLUDED             = 15
```

The 22 unique copies and their seven distinct content hashes are preserved
under `exp-step5-softpll-lock/EXP-S5-FROZEN-FIT-SOURCE-OBSERVER-ARCHIVE-20260924/`;
the existing frozen-fit A/B report remains the result record. The 15 nested
worktrees are separate registered checkouts and are not included in the
regular-file cleanup or counted as safely removable by this audit. The seven
tracked deletions in the old checkout are recoverable from Git and are kept
in a local stash before branch synchronization.
