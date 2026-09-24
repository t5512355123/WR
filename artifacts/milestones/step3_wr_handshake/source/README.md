# Step 3 frozen-source candidate

This self-contained JTAG source package is a **candidate**, not a PASS
milestone. The Step 3 verdict remains pending until this source is clean-built,
programmed on both DE5a boards, and passes the runtime acceptance contract in
`experiments/step3/EXP-S3-MILESTONE-REPRO-20260924/PLAN.md`.

## Provenance

- Historical Step 3 fresh-build report: `EXP-WRPC-STEP3-FRESH-HEAD-20260819`.
- Historical Step 3 source commit: `fb8c926cfe37b82e86300117181a6ac01e1889e2`.
- This build-input snapshot is based on source commit
  `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`. The Git diff between these
  commits contains only `STATUS.md`, `docs/MERGE_READINESS.md`, and the Step 2
  experiment report; no Quartus, generated-IP, firmware, vendor, or script
  build inputs differ.
- `SHA256SUMS` covers all 3,142 source/build-input files in this package.
- The package layout and build/program wrappers use the same documented path
  relocation as the independently rebuilt Step 2 source. No functional RTL,
  firmware, pin, clock, reset, PHY, PTP, or SoftPLL edits were made for Step 3.

The historical Step 3 report names its raw files under an old Pain build
directory that is no longer present. Those old raw files were not found in the
current repository or the reported Pain path. The new reproduction therefore
must use and preserve fresh raw evidence; the historical report alone is not
accepted as this milestone's proof.

## Build and program

On Pain with Quartus Prime Standard 17.0 Build 595 and the required RISC-V
toolchain:

```sh
bash scripts/build/build_master.sh
bash scripts/build/build_slave.sh
```

Program in the order used by the historical Step 3 experiment:

```sh
bash scripts/program/program_master.sh
bash scripts/program/program_slave.sh
```

This is a read-only-observation milestone after programming. Do not power-cycle,
reset, restart PTP, or write runtime control registers during its validation.

## Acceptance boundary

The Step 3 acceptance definition and coherent-frame rules are in the
experiment plan. In particular, use the current `WR_LOCAL state` field to
identify `WRS_S_LOCK`. The separate `fail_state` field is only the state saved
when a prior handshake failure occurred; it is not the current state.

This package is frozen once validated. Later research modifies the repository
root current-development source, never this historical snapshot.
