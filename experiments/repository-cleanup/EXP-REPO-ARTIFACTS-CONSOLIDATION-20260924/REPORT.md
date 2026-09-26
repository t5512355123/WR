# EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924 — Artifact deduplication

## Verdict

`PASS` — artifact-only consolidation. This does not imply that Steps 4–6
milestone reproductions have passed.

## Build and source provenance

No source build was required or performed. Baseline branch and commit:
`feat/file_cleanup` at `61fa7a2b`. No RTL, firmware, Quartus input, or SOF
content was modified.

## Programming sequence and result

No FPGA programming or reset was performed.

## Runtime observations

Not applicable; this was a repository-content audit.

## Analysis and conclusion

The initial tracked-artifact audit covered 161 non-milestone files:

```text
exact Git-blob duplicates in experiments       = 79
transfer archives with all members retained    = 51
verified archive checksum sidecars              = 12
unique tracked files moved to experiments       = 19
```

The physical audit covered 112 ignored/untracked files:

```text
byte-identical copies of retained evidence      = 99 (removed after rehash)
unique historical evidence files                = 11 (moved and preserved)
Step1 milestone SOFs                            = 2 (verified and force-added)
```

All 51 transfer archives had every member matched by SHA-256 against the
corresponding extracted experiment evidence. All 12 present sidecars matched
their archive bytes. The 19 unique tracked files and 11 unique ignored files
were moved, not discarded. The 99 untracked duplicates were individually
rehash-verified by `analysis/prune_verified_duplicate_artifacts.py`; only the
listed files were unlinked. A broad clean preview was not applied because it
would have removed whole ignored directories, including unrelated contents.

Post-cleanup checks found zero physical non-milestone files and zero indexed
non-milestone paths under `artifacts/`. Step1 Master and Slave SOFs are now
tracked and match their README hashes. At the time of this audit, the
historical Step6 SOF pair was under the legacy path below. The Step6
promotion later moved it byte-identically to:

```text
experiments/step6/artifact-import/
  EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/
```

Their hashes remain `6521eb861051ce2fbe283269169992ecb88e093d734012a97500682d74329845`
(Master) and `4775de6007af90e2049bcff573fa4173d843c4d84d25b88490c89a8635adc5ca`
(Slave). They are historical images, not the output of the dashboard-only fix.

The older frozen-fit Step5 pair referenced by the cold/warm replay helpers
(`23bfdc100fa2b61aff3096754ebd99d61c1e1c1728be99cd5515204415c7dd0d` /
`04c7cb7ecca19be16eb9de022891a9c0143b2c6b62ce364d80db4e56508217fc`) is not
present as a SOF in this Laptop checkout. Its hashes remain in historical raw
records; the replay helpers now stop with an explicit message before any
programming if that pair has not been restored.

The initial content-level audit tables are preserved in `analysis/`. They
record source paths, byte lengths, hashes, duplicate destinations, and archive
member coverage.

Repository regression tests: 56 passed using the configured Python runtime
with Git Bash on `PATH`. An initial Windows invocation without Git Bash could
not execute the shell-backed dashboard tests; rerunning with the repository's
Git Bash resolved that host-environment issue. No functional test failed.

## Follow-up repository audit

At worktree HEAD `f0d9f71a7ab8ca5f2e93df478c9bea1ea4ad5c93`, the project-authored
Markdown link audit checked 761 files and 380 local links with zero broken
targets. It intentionally skipped 109 Markdown files copied from vendored
upstream trees, including frozen-source copies. Running with
`--include-vendor-markdown` checks all 870 files and reports 95 broken links;
they are upstream README references to omitted documentation, images, or
unneeded modules, not project-owned paths. Windows absolute workstation links
in archived advice are treated as historical/external references rather than
repo-relative paths. The Step5 advice links affected by the directory
migration were updated to resolve inside this repository.

The `.gitignore` now explicitly permits `artifacts/milestones/**/master.sof`
and `slave.sof`; `git check-ignore --no-index` confirmed the Step4 release
paths are not ignored. No production RTL, firmware, or Quartus build input was
changed by this follow-up.

The Step4 candidate package was rechecked: 3,184 historical source blobs match
the selected source commit, with zero mismatches; all 3,191 files covered by
the relocatable `SOURCE_SHA256SUMS` manifest verified from the source root.
The full repository test suite passed 61 tests. At that point, no Quartus build
or FPGA programming had yet been performed for Step4; the later Step4 build,
program, and runtime reproduction is recorded in
[`experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/REPORT.md`](../../step4/EXP-S4-MILESTONE-REPRO-20260924/REPORT.md).

## Verified legacy archive deduplication

The post-Step4 audit rechecked all 61 tracked transfer archives under
`experiments/legacy/`, including every regular member's basename, byte count,
and SHA-256. It matched 588 members from 48 archives to already tracked
extracted evidence; the 48 archive hashes and all 588 member-to-file matches
are recorded in
[`analysis/legacy-archive-dedup.tsv`](analysis/legacy-archive-dedup.tsv).
Fourteen adjacent checksum sidecars were also verified against their archives
before removal. The 48 archives plus those 14 sidecars were unlinked by the
fail-closed `analysis/prune_verified_legacy_archives.py`; no extracted evidence
was removed.

Thirteen archives remain. Eleven contain 81 members not otherwise extracted
and tracked. Two additional F4B archives are retained because each contains a
unique Master/Slave SOF pair whose extracted local copies are ignored and are
not present as tracked files elsewhere. They were not treated as duplicates.
The remaining 13 archives and all extracted evidence are present after the
cleanup. Archive/member hashes and retained paths are recorded for all 717
regular members in the TSV.

Markdown links that formerly targeted removed archives or sidecars now point
to the extracted raw directory or the audit table. The Markdown link checker
reported 762 authored files, 386 local links, and zero broken links. The
historical report text remains evidence of what was collected at the time; the
legacy evidence policy in `experiments/README.md` explains the later verified
deduplication.

## Canonical-path and stale-reference closure

The final tracked-tree audit found all 19 required current project, build,
program, test, experiment, and artifact entry paths present. The following
obsolete paths have zero tracked files: `CHANGELOG.md`, `docs/architecture/`,
`docs/bringup/`, `docs/migration/`, `docs/reports/`, `docs/experiments/`,
`quartus/rs422_uart_diag/`, `quartus/jtag_runtime_diag_portb/`, nested
`quartus/jtag_runtime_diag/`, root `generated/`, root `tests/`, and
`rtl/clock/si5340_controller/`. The canonical SI5340 RTL is under
`quartus/si5340_controller/`. Root build/program interfaces are the single
JTAG wrappers in `scripts/build/` and `scripts/program/`.

Thirteen historical archives remain, all under `experiments/legacy/`; none
remain outside that directory. `artifacts/` contains no non-milestone
evidence files. The authored-Markdown link audit checked 762 files and 388
local links with zero broken targets.

The only remaining references to retired source/image paths are intentional
and now labelled in the scripts themselves:

- Two Step5 cold/warm historical replay helpers point to the old frozen-fit
  stage. Those exact SOFs are absent from this checkout; each helper checks
  both files and exact SHA-256 values before any privilege check, output
  creation, or programming, then exits without hardware action if unavailable.
- The Step6 Master-last rebuild helper creates a clean detached worktree at
  historical source commit `ec1f25e8`. Its nested `quartus/jtag_runtime_diag/`
  path belongs to that commit's tree and must not be rewritten to the current
  flattened layout.

These are not active build/program interfaces or unresolved current-source
references. Regression tests pass (61 tests), and `git diff --check` is clean.

## Current next action

The Step4 milestone is PASS, with its build/program/runtime evidence in
`experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/`. Repository cleanup and
the canonical-path/stale-reference audit are complete. Next, independently
reproduce Step5 from its own frozen source. Do not substitute a later-Step SOF
for an earlier milestone.

## Evidence

- `analysis/artifact-migration-audit.tsv`
- `analysis/untracked-artifact-audit.tsv`
- `analysis/audit_artifacts.py`
- `analysis/prune_verified_duplicate_artifacts.py`
- `analysis/audit_legacy_archives.py`
- `analysis/legacy-archive-dedup.tsv`
- `analysis/prune_verified_legacy_archives.py`
