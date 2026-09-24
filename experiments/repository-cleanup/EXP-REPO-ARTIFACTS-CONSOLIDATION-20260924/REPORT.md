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
tracked and match their README hashes. The historical Step6 SOF pair remains
available at:

```text
experiments/legacy/exp-step6-global-time/artifact-import/
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
The full repository test suite passed 61 tests. No Quartus build or FPGA
programming has yet been performed for Step4.

## Next action

Review and commit only task-owned changes, then push the cleanup plus the
clearly pending Step4 frozen-source candidate on `feat/file_cleanup`. Pain must
pull that exact commit before the canonical JTAG clean-build check and Step4
candidate build/program/validation. Do not mark Step4 PASS until fresh hardware
acceptance evidence is recorded.

## Evidence

- `analysis/artifact-migration-audit.tsv`
- `analysis/untracked-artifact-audit.tsv`
- `analysis/audit_artifacts.py`
- `analysis/prune_verified_duplicate_artifacts.py`
