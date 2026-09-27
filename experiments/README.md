# White Rabbit experiments

This is the repository's current research-evidence space. New experiment
records belong under the relevant `stepX/EXP-.../` directory and should keep
their plan, report, raw build/program/observation evidence, analysis, and
checksums together when those materials exist.

`step1/` through `step6/` contain the independent milestone reproductions and
their supporting experiment records. Step 6 is the latest completed research
stage; its current status and historical/failed-run index are in
[`step6/README.md`](step6/README.md). `legacy/` contains genuinely older
research and preserved historical snapshots, not the active Step 6 chain.
Historical records describe the source state at the time of each experiment
and are not instructions for the current design.

Some historical reports refer to transfer archives as they existed when the
experiment was collected. Exact duplicate archives may be removed only after
every regular member is SHA-256 matched to a tracked extracted file; unique
members and archives remain. The archive/member-to-retained-file audit is
[`legacy-archive-dedup.tsv`](repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/legacy-archive-dedup.tsv).
The final preservation audit is
[`preservation-audit-final.tsv`](repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/preservation-audit-final.tsv),
and the Step 6 legacy-promotion audit is
[`step6-promotion-audit.tsv`](repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/analysis/step6-promotion-audit.tsv).
The complete final verification note is
[`FINAL-VERIFICATION.md`](repository-cleanup/EXP-REPO-ARTIFACTS-CONSOLIDATION-20260924/FINAL-VERIFICATION.md).

The current development source is at the repository root under `quartus/`,
`quartus_generated/`, `firmware/`, `vendor/`, and `scripts/`. A later-Step image
must never be used to claim an earlier-Step milestone.

Raw logs and checksum-sensitive records must remain byte-for-byte intact.
Do not duplicate the same raw capture in this tree and `artifacts/`; the latter
is reserved for frozen milestone packages. A milestone is `PASS` only after
its own frozen source has been clean-built, programmed on both DE5a boards,
and passed its runtime acceptance criteria.
