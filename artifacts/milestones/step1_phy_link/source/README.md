# Step 1 frozen source — validated milestone build inputs

This self-contained JTAG package is the frozen build input for the Step 1
`PASS` milestone. It was independently clean-built, programmed on both DE5a
boards, and passed the read-only PHY/link acceptance on 2026-09-24. The
reproduction report and raw evidence are in
`experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/`. The historical source
origin, path relocation map, and line-ending normalization are recorded in
that experiment.

## Contents

- `quartus/`: the historical `DE5a_wr_master_jtag` and
  `DE5a_wr_slave_jtag` projects, flattened without renaming either top-level
  entity
- `quartus_generated/`: the generated Arria 10 PHY/PLL/reset IP used by those
  projects
- `quartus/si5340_controller/`: the historical controller RTL
- `firmware/`: historical role configs and firmware build scripts
- `vendor/`: the complete historical vendored WR cores and WRPC software
- `scripts/build/`, `scripts/program/`: the standalone JTAG build and program
  entrypoints for this frozen checkpoint
- `scripts/jtag/read_step1_phy_link.tcl`: read-only instance-0 sampling for
  the Step1 gates
- `scripts/analysis/analyze_step1_capture.py`: offline raw-probe decoder and
  Step1 acceptance check

## Verify the frozen source

Before building on Pain, run `sha256sum -c SHA256SUMS` from this directory.
The manifest covers source inputs, excluding itself, Python caches, and
ignored build outputs. `.gitattributes` keeps text-file line endings stable
across Windows and Linux so the same manifest can be checked on both hosts.

## Rebuild

Use Quartus Prime 17.0.0 Build 595 Standard Edition and the RISC-V GNU tools
available on Pain. From this directory:

```sh
bash scripts/build/build_master.sh
bash scripts/build/build_slave.sh
```

The build scripts first regenerate each role's `wrc.mif`, then run the
corresponding Quartus project. Outputs remain below this source root.
Run the offline analyzer tests with:

```sh
python3 -m unittest scripts.tests.test_step1_capture_analyzer -v
```

## Program

After checking board identity and programmer cables, use:

```sh
bash scripts/program/program_slave.sh
bash scripts/program/program_master.sh
```

The order follows the validated Step 1 procedure. These commands program only
this package's freshly built JTAG SOFs. The milestone PASS evidence is already
recorded in the linked reproduction experiment; a new run is a regression
check, not a prerequisite to promoting this checkpoint.

## Read-only Step1 runtime validation

With both JTAG cables connected and the freshly built SOFs programmed, run from
this directory:

```sh
set -o pipefail
quartus_stp -t scripts/jtag/read_step1_phy_link.tcl 360 100 \
  | tee ../raw/observe/step1-phy-link.log
python3 scripts/analysis/analyze_step1_capture.py \
  ../raw/observe/step1-phy-link.log
```

The Tcl runner reads only probe instance 0; the Python tool decodes the
historical source's exact bit mapping and will not treat an incomplete or
unreadable capture as PASS.
