# Frozen Step 4 source package (candidate)

This package is a standalone copy of the JTAG-only implementation at the
historical source commit recorded in `SOURCE_ORIGIN_COMMIT.txt`. It is a
candidate until its rebuilt Master and Slave images are programmed and pass
the Step 4 acceptance described in the milestone README.

## Layout and provenance

- `quartus/`: the historical Master and Slave JTAG Quartus projects, with the
  project directory flattened from `quartus/jtag_runtime_diag/`.
- `quartus_generated/work_wrphy_full/`: the historical generated PHY/IP input
  tree, relocated from `generated/work_wrphy_full/`.
- `quartus/si5340_controller/`: the SI5340 controller RTL used by the two QSFs.
- `firmware/`, `vendor/`, and `scripts/jtag/`: copied from the historical
  source commit without functional edits.
- `scripts/build/` and `scripts/program/`: the repository's JTAG-only
  reproducible build/program wrappers, adjusted for this package's root and
  carrying the source-origin marker in their build identity output.

The two QSF files and two top-level VHDL files contain only the relative-path
relocations needed by this layout. `experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/analysis/verify_frozen_source.py`
normalizes those path changes and verifies every historical source file
against its Git blob. The source files and wrappers are covered by
`SOURCE_SHA256SUMS`; the verifier reports wrapper files separately because
they are build/program infrastructure, not part of the historical hardware
source commit. Verify package integrity from this directory with:

```sh
sha256sum -c SOURCE_SHA256SUMS
```

## Rebuild

From this directory, using the configured Pain Quartus 17.0 toolchain:

```sh
bash firmware/scripts/build_all_firmware.sh
bash scripts/build/build_master.sh
bash scripts/build/build_slave.sh
```

The build wrappers run Quartus clean/full compiles. They require both
firmware-generated MIF files before Quartus compilation.

## Program and observe

The historical Step 4B reproduction programmed Master, waited approximately
45 seconds, then programmed Slave. Preserve that order for this candidate.
The scripts under `scripts/program/` target the fixed DE5a JTAG cable mapping.

For read-only runtime evidence, use the bundled
`scripts/jtag/read_wb_runtime.tcl --raw` and retain before/after counter values.
Do not perform Wishbone writes, PTP restarts, resets, or power cycles in the
Step 4 reproduction.
