# Step 2 frozen-source candidate

This directory is a self-contained reproduction candidate for the White
Rabbit Step 2 Endpoint / MiniNIC / PTP checkpoint. It is not a PASS milestone
until the report in the parent experiment records successful clean builds,
programming of both DE5a boards, and the complete runtime acceptance window.

## Source provenance

- Historical source commit: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`.
- Historical experiment: `EXP-WRPC-STEP2-DCO-RESTORE-20260819`.
- Historical functional DCO handshake change: commit
  `a427ed3f61a54a704c46cf1e0f650ef591f35de1`.
- The exact historical source tree retains the JTAG projects and top-level
  entities `DE5a_wr_master_jtag` / `DE5a_wr_slave_jtag`.

## Packaging and build path changes

Only the source layout and build/program entry points were adapted for a
self-contained JTAG checkpoint:

- `quartus/jtag_runtime_diag/` was flattened into `quartus/`.
- `generated/work_wrphy_full/` was moved to
  `quartus_generated/work_wrphy_full/`.
- `rtl/clock/si5340_controller/` was moved to
  `quartus/si5340_controller/`.
- QSF and top-level VHDL relative paths were updated to those locations and
  to the candidate-local firmware MIF outputs.
- `scripts/build/build_master.sh` and `build_slave.sh` now build the JTAG
  projects, cleaning the selected Quartus revision before compilation.
- `scripts/program/program_master.sh` and `program_slave.sh` now program the
  corresponding JTAG image. Obsolete RS422 and duplicate `*_jtag` wrappers
  from the historical repository are not included in this candidate.
- Historical production RTL, firmware configuration, role commands, board
  pins, clocks, resets, and timing constraints were not intentionally changed.
- The historical JTAG top-level retains board UART pins for the firmware
  console; this Step 2 build/program/runtime workflow uses JTAG and does not
  depend on that console.

The source manifest, `SHA256SUMS`, is included at this directory's root and
covers its source/build inputs. Successful clean compilation remains the final
authority for Quartus dependency closure.

## Rebuild

On Pain, with Quartus Prime 17.0 Build 595 and the required RISC-V toolchain
available:

```sh
bash scripts/build/build_master.sh
bash scripts/build/build_slave.sh
```

The generated images are:

```text
quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof
quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
```

Program Master with cable `DE5 [1-11.1]` and Slave with
`DE5 [1-11.2]`, using the included `scripts/program/` wrappers. The Step 2
experiment uses the historical order Master then Slave.

## Acceptance boundary

This checkpoint covers endpoint identity, healthy Step 1 link, Master/Slave
PTP roles, MiniNIC/PTP counter activity, and Slave foreign-master metadata.
It does not require WR signaling completion, SoftPLL lock, `PSTAT.locked`, or
global time.
