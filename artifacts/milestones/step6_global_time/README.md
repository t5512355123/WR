# Step6 milestone — two complete root reproductions

**PASS_TWO_INDEPENDENT_ROOT_CYCLES**, qualified 2026-10-02.
Also **PASS_FRESH_STANDALONE_MILESTONE_REPRODUCTION** after a new full
build/compile/program/capture run from this package at 20:03–20:34.
See [standalone rebuild verification](STANDALONE-REBUILD-VERIFICATION.md).
This directory contains **one** operational Step6 version, not a mixture of
old source and a newer `current/` tree. Root-level SOFs, archived output/SOFs
and current main-root output are the actual second-cycle pair.

## Contents

- `source.tar.gz`: root source, scripts/dashboard, firmware/vendor/generated
  Quartus inputs, retained build/output products and both-cycle experiment data.
  No external milestone/source tree, Git history, compiler cache or toolchain
  installation is embedded. `source/` is its extracted form, not another version.
  Snapshot checkout: `0bb02c6f91dd4c7a578e1b8cb02a553ce9ce9787` (production
  inputs remain the identical qualified second-cycle inputs). The snapshot's
  `output/PUBLISHED_SHA256SUMS` is the parent repository's release index and
  also lists Steps 1–5; those packages are deliberately not embedded here.
  For standalone verification use `ARCHIVE_SHA256SUMS`, `SHA256SUMS` and the
  extracted `output/SOURCE_SHA256SUMS` / `output/SHA256SUMS`.
- `master.sof`, `slave.sof`, `SHA256SUMS`: actual qualified second-cycle images.
- `ARCHIVE_SHA256SUMS`: exact archive hash.
- `prepare_source.sh`: verify, extract, verify production inputs/images and
  create an independent Git index needed by the original build/export scripts.
- `VERIFICATION.md` and `verification-dashboard.log`: packaging integrity and
  same-live-session usability check, separate from the two fresh hardware cycles.

Requirements on Pain: Quartus Prime Standard 17.0.0 Build 595 installed at the
configured `/mnt/ds1515/opt/intelFPGA/17.0/quartus` path, the existing RISC-V
firmware toolchain, Python3/Bash/Git and both DE5a JTAG cables. These installed
tools are dependencies, not copied compiler installations.

## Use the retained qualified images first

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step6_global_time
bash prepare_source.sh
cd source
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

Programming is Slave then Master. Stop the dashboard with Ctrl+C before any
other JTAG reader/programmer. Startup is not instant: both successful fresh
cycles acquired TIME_VALID after about 130 seconds. A WAITING reading during
acquisition is not a passed dwell; never force validity or declare PASS from
one dashboard frame. To validate again after stopping the dashboard:

```sh
bash scripts/monitor/verify_time_valid_300s.sh
```

It waits boundedly for acquisition, then captures each board for 303 seconds
at requested 250 ms intervals and requires a ≥300-second valid sample span.
Boards are observed sequentially, so allow about 10 minutes plus acquisition.

## Four steps to rebuild from this frozen source

From the prepared `source/` directory:

```sh
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

Fresh products are in this directory's `output/DE5a_wr_master_jtag.sof` and
`output/DE5a_wr_slave_jtag.sof`; firmware products are in `build/firmware/`.
The initial standalone Git commit is packaging identity, not the original
compile commit. Fresh compiles record their own source identity and hashes.
Before rebuilding, `output/SOURCE_COMMIT` correctly records the original
second-cycle compile `7b6550123986a9d7cea5f4be0dbb8af1f5a019ab`.

## Qualified scope and exact version

Only production modification: Master `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP`
34 → 64. Master bootstrap 2048, Slave `/2 acquisition + /12 tracking` and
all other firmware control inputs were unchanged. Master Helper was locked
and phase tracker ready after qualification.

| Cycle | Master TIME_VALID | Slave TIME_VALID |
|---|---|---|
| 1 | 1192/1192 over 302791 ms | 1192/1192 over 302901 ms |
| 2 | 1192/1192 over 302815 ms | 1192/1192 over 302885 ms |

Both cycles were main-root fresh build → full compile → program → capture,
not two reads of the same boot. All 3110 production hashes and both MIFs matched.
All four windows had zero invalid rows, max gap ≤258 ms and no transport errors.
Complete records/report are included at
`source/experiments/step6/EXP-S6-MASTER-HPLL-STEP64-REPEATABILITY-20261002/`.

Master SOF SHA256: `9f66cef3f06697085325916126e6da61d76ace7138e7203af068df1a69d30036`.
Slave SOF SHA256: `b92e3356580691814e113e8c3278f1044bee621e2808d207541c9efc3ba59727`.

This is the user's TIME_VALID-only ≥300-second sampled acceptance. It does
not establish offset <60 ps, physical SMA skew, absolute time correctness,
validity between samples or universal startup reliability. Timing closure is
not required. Earlier byte-identical packages failed after reprogramming;
their single-session PASS is not substituted for these new two-cycle records.
Old packages are recoverable from Git history/separate backups, not inside
this milestone. The protected server archive was not accessed or modified.
