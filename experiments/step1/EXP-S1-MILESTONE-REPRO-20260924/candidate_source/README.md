# Step1 JTAG source candidate (not yet validated)

This directory is a readable, self-contained reconstruction candidate from
historical source commit
`b8d4c3d0526f0c2ca282600ef06648dd9f0af595`.

It is **not a PASS milestone** yet. Do not treat these files as the current
Step7+ development source. The historical source origin, path relocation map,
and line-ending normalization are recorded in the parent experiment's
`PLAN.md` and `analysis/source-relocation.md`.

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
  entrypoints for this candidate
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

The order follows the 2026-08-17 Step1 historical procedure. These commands
program only this candidate's freshly built JTAG SOFs. Runtime validation is
still required before this candidate can become `artifacts/milestones/step1_phy_link/`.

## Read-only Step1 runtime validation

With both JTAG cables connected and both candidate SOFs programmed, run from
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
