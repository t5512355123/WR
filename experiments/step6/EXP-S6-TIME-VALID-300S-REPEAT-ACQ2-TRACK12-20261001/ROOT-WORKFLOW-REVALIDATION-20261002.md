# Root workflow revalidation — 2026-10-02

## Scope

Promote the proven acquisition `/2`, tracking `/12` controller to the root
source tree. No experiment-local patch or historical worktree is required.
All production C/RTL differences from the validated frozen Step6 source
are exactly the two servo divisions. Existing passive observer changes are
preserved. The protected Pain archive was not changed.

Four entrypoints: `scripts/build/build_current.sh`,
`scripts/build/compile_current.sh`, `scripts/program/program_current.sh`,
`scripts/monitor/step1_6_dashboard.sh`. Existing per-board firmware/compiler/
programmer scripts implement these aggregate steps.

## Build and programming

- Actual root compile commit: `073c9afabd52272f4de40bd70592aa75eab1c60a`.
- Operational wrapper commit: `05f54444` (source-equivalent; observer/documentation/export changes).
- Quartus: 17.0.0 Build 595 Standard Edition, both full compilations successful.
- Master MIF: `07511e0a1148dd120898b1fc53f644f265b098d52912340314dace2a8b1526f6`.
- Slave MIF: `d6165e93f0a43bc6b2a41db8d568ab696916c1a32c1733b47d7df36b5a692916`.
- Both MIFs match the previous successful candidate exactly; firmware version
  text is pinned, while actual root checkout identity is recorded separately.
- Master SOF: `c6bf538396ff404e8cefab91f1fe13c2f348d8ef71bfbff5fc7f64b069397818`.
- Slave SOF: `fa0dd01c2469ebef10b11dedb5cdf88ed7d2da74f71fe4a5a1f4ee45a29dba3d`.
- Fresh Slave then Master programming succeeded, zero errors/warnings.
- Timing closure remains NO and is not this acceptance gate.

The two current SOFs and complete Quartus output reports are in `output/`;
firmware ELF/BIN/MIF and build logs/metadata are in `build/`. Compiler object
workspaces, Quartus databases and incremental caches are rebuildable staging,
not published release files. All twelve existing Step1–6 milestone SOFs are
tracked and their checksums were verified unchanged.

Every compile/export also saves a unique, timestamped build record under
this experiment's `raw/build/`, so subsequent root builds cannot overwrite
the historical firmware and compile logs. This reproduction's archived
record is `raw/build/20261002T012631Z-current.3tphJU/`. Its post-transfer
checks confirm all 64 published files and all 3110 source inputs match.

## Hardware acceptance

Capture run: `20261002T010427Z`. Read-only, one JTAG reader, sequential boards,
303,000 ms requested per board, 250 ms sampling interval.
The only functional acceptance signal is exported `STATUS_TIME_VALID=1` for
every sampled row, spanning at least 300,000 ms on each board. Transport,
board identity, sample sequence, capture completion and sample-gap checks
also must pass. This is a sampled-bit test, not cycle-by-cycle continuity,
simultaneous inter-board timestamp equality, or a physical edge-skew test.

Final verdict: **PASS_TIME_VALID_300S**, both boards, complete capture,
no transport errors, no invalid rows, valid sample identity and sequence.

| Board | TIME_VALID=1 / samples | First-to-last sample span | Max gap |
|---|---:|---:|---:|
| Master 1-11.1 | 1190 / 1190 | 302868 ms | 257 ms |
| Slave 1-11.2 | 1190 / 1190 | 302813 ms | 257 ms |

PPS-valid, snapshot-valid/time-valid and Step1-ready were also 1190/1190
on each board, and live time was monotonic; these are diagnostic observations,
not extra acceptance gates. The capture elapsed times were 303123 ms and
303067 ms. See `analysis/20261002T010427Z-current-time-valid-300s.json` and
`raw/observe/20261002T010427Z-current-time-valid-303s.log` (each with checksum).

Post-capture live dashboard exited successfully; both boards displayed
Step6 VALID, TIME_VALID=1 and PPS_VALID=1. Saved as
`raw/observe/20261002T010427Z-current-dashboard.log`. Its two PPS snapshots
were read sequentially, so the displayed TAI values are not a same-edge
comparison and must not be treated as inter-board time offset.

Nine source/300-second-acceptance tests and the broader 28-test dashboard/
observer regression group passed. Shell syntax checks passed for the root
workflow. Historical archive Markdown contains pre-existing broken links;
that archive evidence was not rewritten to make a link checker green.
