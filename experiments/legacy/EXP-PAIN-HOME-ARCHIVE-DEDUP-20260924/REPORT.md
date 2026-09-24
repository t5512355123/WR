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
| `experiments/legacy/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/sta/DE5a_wr_master_jtag.sta.summary` | `b7f579467bbe949eafa0dc1886ef87beeccb174d674846a154de1bc833b25160` |
| `experiments/legacy/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/sta/DE5a_wr_slave_jtag.sta.summary` | `a9582025d5dfaf64d4def525e103c8de2e65b00c41ff70cc9c182a9d79fd9020` |
| `experiments/legacy/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/fit/DE5a_wr_master_jtag.fit.summary` | `fd533c013940af8f4b696908731eb810b1520bea9b18aedab9a987d34d12893b` |
| `experiments/legacy/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/fit/DE5a_wr_slave_jtag.fit.summary` | `d823d29ddb80ef79b6f1afd19a07b43fb2fa4fcc75e5f5be4dba6abf24d6dd45` |
| `experiments/legacy/exp-step5-softpll-lock/EXP-S5-DIAG-ACTIVITY-CDC-CONSTRAINT-FIX-20260920/raw/pre-pull-raw-20260920/file-sha256.txt` | `48ff9a52b0e64a6d98b4b3c01966136eb25bc9479a69bb3a5c50c5af58a0d5cd` |
| `experiments/legacy/exp-step5-softpll-lock/EXP-S5-FAST100C-SYSCLK625-HOLD-PATH-AUDIT-20260920/raw/pre-pull-raw-20260920/file-sha256.txt` | `55c244e59866e92fd85bb016ff36d3287497781351cc443f53165d9fbd342f11` |
| `experiments/legacy/exp-step6-global-time/EXP-S6-SLAVE-PTP-RESTART-WR-EXTENSION-RECOVERY-20260922/raw/observe/ptp_restart_recovery_pre_pull.log` | `2eb570a979fef7b4d88e6338db24f815b296071281ba1378f1024f317dd2b5ca` |
| `experiments/legacy/exp-step6-global-time/EXP-S6-GLOBAL-TIME-LATE-RECOVERY-TAIL-STABILITY-20260922/raw/observe/late_recovery_tail_pre_pull.log` | `7372cf01fce4da4685366dc519941165f5e17d395bca0fb7428ae7e06bef7b47` |
| `experiments/legacy/exp-step6-global-time/EXP-S6-SAME-PPS-GLOBAL-TIME-CONSISTENCY-20260922/raw/observe/same_pps_consistency_pre_pull.log` | `274b5068267c3c19afe411b9626dd431f76272be5496ce4e349374855dccb30e` |

## Cleanup status

The recovered records and this audit were pushed to GitHub and verified in
Pain's clean GitHub checkout at commit
`a1444f1e005501e93276604ec24e7250f08fd203` before cleanup. On 2026-09-24, all
twelve exact source directories in the table were revalidated and removed:
281 files total, with no symlinks, special files, SOF, or MIF. Their contents
remain recoverable from Git: 272 were exact duplicates already tracked at the
pre-archive baseline and the other nine are versioned at the paths above.

The active Pain checkout, `snap`, and `share` were not touched.

An additional eight exact backup directories were audited on 2026-09-24:
the four `step4b-remote-raw-backup-*` directories, three `WDIAGS-*-raw-backup-*`
directories, and `WR_local_log_backup_20260828`. Their 65 regular files
(3,675,034 bytes) all matched blobs already present in the fetched
`origin/feat/file_cleanup` tree. There were no symlinks, special files, SOF, or
MIF files. The eight duplicate directories were then removed; their contents
remain recoverable from Git.

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
the existing frozen-fit A/B report remains the result record. The other 468
copies were already present in Git at the same or an alternate path. After
verifying all 490 files against the fetched `origin/feat/file_cleanup` tree,
the duplicate working copies were removed from the old checkout. The 15
nested worktrees were deliberately left untouched for a separate audit.

The old checkout's seven tracked deletions were saved in a new local stash
(`preserve pre-cleanup root tracked deletions 20260924`); the two pre-existing
stashes were retained. The primary `/home/b10504072/04_WR` checkout was then
switched to `feat/file_cleanup` at `b769ea1a30665b2b32624b52a0e0a9d8cff04511`,
which matches `origin/feat/file_cleanup`. The staged/uncommitted contents of
the remaining registered worktrees are still under audit and have not been
removed.

## 2026-09-24 follow-up: /04_WR/pain-worktrees

The seven linked worktrees immediately below
/home/b10504072/04_WR/pain-worktrees/ were re-audited against the synced
origin/feat/file_cleanup at 4a06256c472ab6c4d243f6b60284a6924b0d68eb.
Every worktree HEAD is an ancestor of that branch, and no active remote
process referenced these exact paths at the time of the audit.

| Worktree | HEAD | Status entries |
| --- | --- | ---: |
| EXP-S5-300S-KI1-20260920 | 26e138fdc0bfc8426704b397141d563cf4d580a2 | 5 |
| f4l-lane0-c4095e75 | c4095e7535d1e179e5aef88d2c8ee61130275a88 | 0 |
| main-latest | 2813081678afa380356c60e4e3dcd17843b258c2 | 0 |
| qsfpa-f4h-exact-898b041 | 898b041afa2fcd6ca48a84eb7326eebc419ac4a3 | 14 |
| qsfpa-lane0-restore-ef3223ad | ef3223adb0fa226f9e412e179c1d963ce11f4574 | 0 |
| qsfpb-startup-gate-5ef4dc15 | 5ef4dc156ba6d1b11017285bf4c4fd366255afaa | 11 |
| step6-global-time | cee492a4960933b5084a34b8dd256211af5d8bfa | 51 |
| **Total** |  | **81** |

All 81 modified/untracked file contents in the four non-clean worktrees were
compared by Git blob ID against the current feature-branch tree. All 81 had an
exact tracked-content match, with zero unique blobs. The tracked source and
research data in all seven worktrees therefore remain recoverable from GitHub.

Their twelve generated SOFs were separately SHA-256 checked:

| Worktree | Master SOF SHA-256 | Slave SOF SHA-256 | Classification |
| --- | --- | --- | --- |
| EXP-S5-300S-KI1-20260920 | a2945df48fe86038fdff138f4b6368a777fa3df13f98ac9620fb30baa1ee0129 | 7462d94a521f52e7660295a6873de5141658fbf5392d90a4d4ade7d4e5f36f50 | Exact duplicate of the retained Step5 milestone pair |
| f4l-lane0-c4095e75 | a5c6af94b658340bd0ebe39a8c178358ed322f468cb27331d6b23bd1c7752dba | 17c527a68a58377ee4efab2961fe2ea6bb593d0e78b4f741d0a01af6132f5e8a | Non-milestone build |
| qsfpa-f4h-exact-898b041 | f40eeb1046381fcfd186618a4f66a0cbe6571fa449f5e4fc525b679a064b5532 | 1a3201d001355944d74fc4191317f79711ec9389c2f4410e93e727be9e881750 | Non-milestone build |
| qsfpa-lane0-restore-ef3223ad | 9fec958572546984e26571511034d5661c41720772b25f0188d559b9aecba5a0 | 7b0dfae8408b9fc45e22c2bfc841d384a7e16a6adb68f72f7f0b4079a6daa63c | Non-milestone build |
| qsfpb-startup-gate-5ef4dc15 | eb82c7ee30bb8e9d8f8c3dca84667f47525760a02a9fccf30bb2e38a059dd7a8 | d87775cd6ce0de2250a3b0ef9a7e22c7c338cb162dd3b607640a0dffe978e269 | Alternate-port diagnostic, not a Step1/5/6 milestone |
| step6-global-time | 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5 | 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151 | Non-milestone predecessor build; current Step6 pair retained elsewhere |

For this comparison, the retained milestone hashes are Step1 Master/Slave
9238740e35f2b48915d1fa7ee6d2dca9d443438f197f1226720dde9dd5e1892b /
44251d6911c021e0d6fb12083034ec870a7d06a4374e435d27caa5e9efb36f15,
Step5 Master/Slave
a2945df48fe86038fdff138f4b6368a777fa3df13f98ac9620fb30baa1ee0129 /
7462d94a521f52e7660295a6873de5141658fbf5392d90a4d4ade7d4e5f36f50, and
Step6 Master/Slave
6521eb861051ce2fbe283269169992ecb88e093d734012a97500682d74329845 /
4775de6007af90e2049bcff573fa4173d843c4d84d25b88490c89a8635adc5ca.
The two Step5 copies in the first worktree are retained in their canonical
artifact folder; the other ten generated images are not milestone images.

## 2026-09-24 follow-up: retained images and remaining Pain scratch

The synced checkout was re-audited at `5783a0f2`. The 151 regular SOF files
under `/home/b10504072/04_WR` total about 5.55 GB. Exact SHA-256 comparison
against the documented Step1, Step5 300-second PASS, and latest Step6 artifacts
found only these six canonical images:

| Milestone | Canonical files |
| --- | --- |
| Step1 | `artifacts/EXP-BASELINE-RS422/master.sof` (`9238740e35f2b48915d1fa7ee6d2dca9d443438f197f1226720dde9dd5e1892b`); `slave.sof` (`44251d6911c021e0d6fb12083034ec870a7d06a4374e435d27caa5e9efb36f15`) |
| Step5, 300-second functional PASS | `artifacts/EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/DE5a_wr_master_jtag.sof` (`a2945df48fe86038fdff138f4b6368a777fa3df13f98ac9620fb30baa1ee0129`); paired Slave SOF SHA-256 `7462d94a521f52e7660295a6873de5141658fbf5392d90a4d4ade7d4e5f36f50` |
| Step6, S_LOCK restart fix | `artifacts/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/DE5a_wr_master_jtag.sof` (`6521eb861051ce2fbe283269169992ecb88e093d734012a97500682d74329845`); paired Slave SOF SHA-256 `4775de6007af90e2049bcff573fa4173d843c4d84d25b88490c89a8635adc5ca` |

The other 145 SOF files are noncanonical diagnostics/rebuild outputs; their
pre-clean SHA-256 and relative paths are preserved in
`nonmilestone-sof-prune-manifest.tsv`. The historical Step4B SOFs
(`94244a9e...` Master and `83a6ae95...` Slave) are absent from Pain and from
the full Laptop `04_WR` SOF inventory. The source-matched rebuild also differs
byte-for-byte, so it is not substituted or labelled as the validated Step4B
milestone; details are recorded in the Step4B identity-audit report.

The exact standalone MIF hashes recorded by the Step4B and Step5 milestones
were searched under Pain's home and not found. The canonical Step1 MIFs remain
at `artifacts/EXP-BASELINE-RS422/{master,slave}.mif` with SHA-256
`0d7e79f0a33d82b5afaf850e19c169bb88ea479a58029f9c19b60de561ccb5f2` and
`9a9c23628ef235c6cb24376c039120bf06b2dac5d213374fc591e6f5992d1c19`.
Step6 MIFs remain beside the Step6 SOFs with SHA-256
`00cf52190ae60392fce14fcb23ffac6adcb82b3a9ca4de5d1e968d21e3c68681` and
`066761f51af3cc279923bd1e349b33d2d311faa7d2fa23e43745d9a1da3ca33c`.
Step5 SOFs embed the firmware image; no claim is made that the separately
recorded Step5 MIF files are currently retained.

The remaining 28 secondary linked worktrees were rechecked: 27 are clean; the
single modified `task-diags.c` file has blob
`1cfbd9216cba78e0958b46fb781a99fe8a9fe44b`, already present in commit
`61b9aa8c2a374ec5f400b0a143b12b2ba0bbec25`, which is an ancestor of
`origin/feat/file_cleanup`. All 28 HEADs are reachable from that branch and
no Quartus/JTAG process was active. They can be removed without losing
versioned source or unique uncommitted source.

The user-requested `/home/b10504072/snap` (144 KB) contains only
snapd-desktop-integration-generated user-directory settings and caches;
`/home/b10504072/share` (192 KB) contains only libpng manual pages. Neither
contains research data. These exact folders are included in the cleanup scope.

## Cleanup completion check

On Pain, every one of the 145 manifest entries was re-hashed immediately
before removal and matched its recorded SHA-256. All 145 noncanonical SOFs
were removed; a fresh full-tree inventory found exactly the six canonical
Step1, Step5, and Step6 SOFs listed above, each still matching its expected
hash. The 28 secondary worktrees were removed after the source-reachability
and dirty-file checks; the main checkout is the only registered worktree.
The exact `/home/b10504072/snap` and `/home/b10504072/share` directories are
absent. At this checkpoint Pain's `feat/file_cleanup` HEAD and
`origin/feat/file_cleanup` both equalled
`704409e75a678821f6bf5dc2b6934fb38215fe06`, and the tracked working tree was
clean; later report commits and syncs are recorded below.

## 2026-09-24 follow-up: preserved unique raw evidence

A content-level audit covered 17 top-level `pain-preserve*`/pre-pull
directories (124 regular files, no symlinks). Of those files, 107 have exact
Git blob matches in the synced feature branch; the other 17 unique files
(total 7,563,442 bytes) were copied byte-for-byte
under `raw/unique-preserved/`. Each archived file's Git blob ID matches its
Pain original; SHA-256 and byte count are recorded in
`preserved-unique-raw-manifest.tsv`. The preserved set includes the unique
pre-reseat WR-link observations, the Step6 ext-disable observation, Master
Quartus build reports for the TX-comma investigation, and Step6B timing logs.

These archive directories contained no SOF or MIF files and no symlinks. The
new raw archive and manifest were pushed and verified on Pain before the old
top-level copies were removed. All 124 original file contents remain
represented either by the existing feature-branch blobs or by the new raw
archive. The separate `archive/` source/history collection (1,185 files,
about 16 MB) is not a duplicate backup and remains untouched.

## Archive-directory cleanup verification

Pain pulled commit `a5fb503a` before the final archive audit. All 124 files in
the 17 listed top-level pre-pull/archive directories were rechecked against
the current Git tree: 107 were exact blobs already versioned and all 17 unique
files matched their newly archived copies by SHA-256, Git blob ID, and byte
count. There were no symlinks, special files, SOF, or MIF files in these
directories. The 17 exact directories were then removed; the 17 unique files
(7,563,442 bytes) remain in `raw/unique-preserved/`, and no unique research
data was lost.

The empty nested `/home/b10504072/04_WR/04_WR/` contained only an
`artifacts/EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3072-REVERSE-20260909/` directory
chain and no files or links; the chain was removed with `rmdir` after the
empty-only check. A final remote inventory confirmed exactly six SOFs remain,
the only registered worktree is the primary checkout, and all explicitly
listed home-level backup names are absent. The separate `archive/` source/
history collection and required project source directories remain untouched.

## 2026-09-24 follow-up: laptop SOF inventory and Step4B recovery

A full Laptop SOF inventory found 21 images: the two-image Step6 pair already
retained as canonical on Pain and 19 additional images. Reviewing the
experiment reports showed that the 2026-09-15 F4B arbitration control pair
is a valid, source-proven Step4B gate-pass build: both boards were clean-built
and programmed, the settled retry reported Step4B PASS, and the report explicitly
keeps Step5 as incomplete. Its exact images are therefore retained as the
Step4B artifact, not as a Step5 pass:

| Board | Canonical path | SHA-256 |
| --- | --- | --- |
| Master | `artifacts/EXP-STEP4B-F4B-ARBITRATION-CONTROL-20260915/DE5a_wr_master_jtag.sof` | `ae017c25ca628f7c7d35636d27079f85e8f5543aa8f712e122f984f5a6932400` |
| Slave | `artifacts/EXP-STEP4B-F4B-ARBITRATION-CONTROL-20260915/DE5a_wr_slave_jtag.sof` | `ec4be4bd6390ce2cbe3c603c99b337fb501d60da37e58c2cf2b5bfca1de5f092` |

The original Step4B SOF pair from the 2026-08-29 repeat experiment remains
absent and its exact identity is not claimed to be restored. The 2026-09-15
pair is a separately validated Step4B image set. It was restored to the
canonical artifact directory on both Laptop and Pain and re-hashed after
copy. The Step4B rebuild-identity report records this distinction.

The other Laptop-only SOFs were classified from their reports: Step4 event
and runtime-context builds did not pass Step4; the Step2/3 regression build
was not programmed; the WDIAGS mapping self-test passed only its mapping
contract; the mixed-candidate F4B image was provenance-contaminated for
Step5; the slave-only candidate was blocked upstream; and the TX-comma image
did not pass its Step6A gate. Their reports and raw measurements remain
intact. Their exact binary hashes and original paths are recorded in
`laptop-nonmilestone-sof-prune-manifest.tsv`; duplicate copies of the selected
Step4B pair are recorded as deduplications to the canonical artifact paths.

Pain's current full SOF inventory was rechecked after restoring the Step4B
control pair: exactly eight images remain, comprising Step1, Step4B, Step5,
and Step6 Master/Slave pairs. The Laptop now also has all eight canonical
images, with the Step1 and Step5 pairs copied from Pain and their SHA-256
values verified. It still has the 19 additional paths listed in
`laptop-nonmilestone-sof-prune-manifest.tsv` (17 non-milestone files and two
old-path copies of the selected Step4B pair). The shell safety layer refused
the requested local delete operation, so no local files were removed in this
follow-up; the laptop-only cleanup remains pending. The experiment reports,
source, raw measurements, and non-SOF research data remain intact. The
2026-08-29 Step4B identity audit still applies to that older pair; this
follow-up does not rewrite its hashes.
