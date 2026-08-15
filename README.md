# DE5a White Rabbit

This repository is the source-of-truth staging repository for the DE5a Arria 10 White Rabbit project.

## Hardware

- Terasic DE5a / Arria 10
- White Rabbit core (`xwr_core`)
- Arria 10 WR PHY
- QSFP-A lane 0 for the WR 1 GbE link
- QSFP-B reference clock for the approximately 124.992 MHz DMTD clock
- SI5340/DCO clock control
- uRV RISC-V soft CPU
- PPS output to SMA_CLKOUT

## Repository rules

Source, build inputs and documentation are versioned. Quartus databases and ordinary build outputs are ignored. A milestone SOF/MIF/report/probe set belongs in `artifacts/EXP-XXX/` with `metadata.md`.

The original Laptop and pain projects are preserved outside this repository. The migration evidence is in `docs/migration/`.

Source, generated input and milestone artifact rules are summarized in
`docs/migration/05_reproducibility_audit.md`. Path mapping and unresolved
Laptop/pain conflicts are in `docs/migration/06_path_mapping.md` and
`docs/migration/07_open_decisions.md`.
The branch, build, artifact and recovery rules are in `docs/git_workflow.md`.

## Current status

Read `STATUS.md` first. The current baseline proves FPGA configuration and PHY/PCS link, but does not yet prove White Rabbit time synchronization.

## Build on pain

```sh
scripts/pain/pain_status.sh
scripts/build/build_master.sh
scripts/build/build_slave.sh
```

The scripts use Quartus Prime 17.0 by default and require the exact MIF files under `build/firmware/` before compilation.
The build identity records the Git commit, Quartus version, QSF/SDC/MIF/SOF
hashes, Fitter status, timing slack and unconstrained-path counts. A successful
compile does not imply timing closure; consult `STATUS.md`.

## Firmware

```sh
firmware/scripts/build_master_firmware.sh
firmware/scripts/build_slave_firmware.sh
```

The scripts build from a temporary copy of the vendored `wrpc-sw` tree so that the checked-in source tree is not modified by Kconfig or generated files.

## Programming and evidence

```sh
scripts/program/program_master.sh
scripts/program/program_slave.sh
scripts/experiment/collect_artifacts.sh EXP-XXX
```

Use the experiment template in `docs/experiments/EXP-XXX_TEMPLATE.md` and record the exact Git commit, MIF, QSF, SDC, SOF and probe evidence.
