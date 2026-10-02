# Frozen Step6 milestone: fresh standalone reproduction

Result: **PASS_FRESH_STANDALONE_MILESTONE_REPRODUCTION**, 2026-10-02.

This is a new full build/compile/program test of the frozen package, not a
same-live-session dashboard check and not reuse of main-root output.

## Exact source and complete pipeline

Working root:
`/home/b10504072/04_WR/artifacts/milestones/step6_global_time/source`.
Independent Git source/compile identity:
`6f298267cf578d051689db451f1b856b380ad1f6`.
The package snapshot originated from `0bb02c6f`; the standalone Git identity
differs because `prepare_source.sh` creates a local independent repository.
All **3110** production input hashes match the main-root qualified inputs,
both before and after the build. Production code/control settings unchanged.

Started **20:03:23**, completed **20:34:23** (+08:00), 31 minutes.
Packaged original scripts ran firmware build → full clean Master/Slave FPGA
compiles → Slave then Master programming → preflight dashboard → acquisition
→ sequential two-board 303-second captures → final dashboard.

Both MIFs matched the pinned qualified hashes:

- Master: `18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea`.
- Slave: `91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379`.

Both full compiles succeeded. Timing closure remains NO and is not the gate.
Programming used the new `source/output/` images, with zero programmer errors
and warnings. Slave programming ended **20:20:20**, Master **20:20:38**.

## Actual fresh images

| Board | SHA256 |
|---|---|
| Master | `5ac122d17959199f0a6a73c4b6e744f054a44f3bc5cff7fc9e5290752d8a6351` |
| Slave | `35db78d9d8bf969f91a9049e2592d921827c41d9dbe86a65c943e73c4fa33ac4` |

These fresh compile products differ in bytes from the previous retained pair;
their actual SHA256s match both board build metadata and captured SOF copies.
They are retained in `raw/rebuilt/output/` and `raw/cycle/`, while the live
standalone outputs remain at `.../step6_global_time/source/output/` on Pain.
No main-root output or original milestone alias was overwritten.

## Acquisition and 300-second result

The immediate post-program dashboard correctly showed Master valid while
Slave remained UNINITIALIZED/WAITING. Master Helper was initially unlocked.
Both TIME_VALID bits became qualified around **180 seconds** into the
readiness observer (last incomplete poll 167 seconds, successful poll about
180 seconds). This was slower than the preceding two root runs (~130 s),
but within the unchanged 1800-second readiness bound. All readiness logs
are retained; no early WAITING frame was counted as a passed dwell.

| Board | Valid samples | Sample-to-sample span | Capture elapsed | Largest gap | Invalid rows |
|---|---:|---:|---:|---:|---:|
| Master DE5 [1-11.1] | 1192/1192 | **302952 ms** | 303206 ms | 257 ms | 0 |
| Slave DE5 [1-11.2] | 1192/1192 | **302872 ms** | 303126 ms | 256 ms | 0 |

No capture errors; complete board identities, DONE sample counts and sample
sequence checks passed. TIME_VALID, PPS/snapshot validity and link gates were
high in every capture row; live time progression was monotonic. The formal
gate is exported STATUS_TIME_VALID, sampled sequentially per board at a
requested 250 ms interval. No rows were dropped or masked.

Final dashboard at **20:34:15** showed both TIME_VALID=1 and PPS_VALID=1.
Master Helper=1; Slave Helper/Main frequency/Main phase/Main lock/PSTAT=1.
The dashboard's separate Step5 stability classifier remained INFO; this
one-shot sample is not an independent 300-second Step5 lock qualification.
Slave phase offset was +3917 ps, diagnostic only, not a failed TIME_VALID gate.
Master/Slave TAI labels were 809/813; equal absolute labels/physical alignment
are NOT established by this run and must not be inferred from TIME_VALID.

## Independent verification and preservation

Pain produced `PASS_TIME_VALID_300S`. The checksummed evidence bundle was
transferred to Laptop (SHA256
`02a3797a18d7d649f457fa7d41ed12f6fea82d9f5178841f68d7e336a8b00645`).
Laptop reran the raw capture analyzer and `analysis/audit.py`, verifying the
standalone working root, all pipeline stages, actual compile/program image
identities, complete production manifest and each board's ≥300-second gate.
Independent verdict: **PASS_FRESH_STANDALONE_MILESTONE_REPRODUCTION**.

Original `source.tar.gz` remains
`54950148ab09c0a5367f9779e59eaf993fcbef66877b8e7e461d642f8c7e2598`;
original milestone aliases remain Master `9f66cef3...`, Slave `b92e3356...`.
Only extracted generated build/output/cache/evidence changed. There is still
one Step6 operational code version. No advisor, power cycle, parameter change
or protected-archive access was used. Records under `raw/` include pipeline,
compile, firmware, programmer, readiness, capture, pre/post dashboards and
checksums; `analysis/independent-laptop-audit.json` preserves the offline result.

PASS is sampled TIME_VALID ≥300 seconds on each board. It does not prove
cycle-by-cycle continuity, offset <60 ps, absolute time accuracy, physical
SMA skew, timing closure or that every future boot will acquire identically.
