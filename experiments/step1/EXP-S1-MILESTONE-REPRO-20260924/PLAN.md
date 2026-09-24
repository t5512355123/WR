# Step1 JTAG milestone reconstruction

## Objective

Rebuild and revalidate the first White Rabbit checkpoint from its own frozen
JTAG source: PHY ready, RX/TX ready, TM link up, core link healthy, and no
persistent encoding errors on both DE5a boards. PTP lock, WR handshake,
SoftPLL, and global time are not Step1 acceptance requirements.

## Candidate provenance

- Historical experiment: `EXP-WRPC-BASELINE-RESTORE-20260817`
- Historical source commit: `b8d4c3d0526f0c2ca282600ef06648dd9f0af595`
- Quartus: Prime 17.0.0 Build 595 Standard Edition
- Historical Master SOF SHA-256: `25567908d38334491b1b7e25f5bd3a8c890743d541e2a3cf72ab2031a54e33be`
- Historical Slave SOF SHA-256: `0d4528b3cb2a26ae3c20b3cc395481441ebb81385c87c9e93ff4923aec63edc5`
- Historical Master MIF SHA-256: `968e3863f2622fe67d468327bec1d8832e955344f74973cde7e2bc19fcf7347d`
- Historical Slave MIF SHA-256: `88f5dce3198e17ad75933e353c9852fdd43069ebc92b7e94734c0db9c270cfef`
- Historical runtime evidence: both JTAG images programmed; Master and Slave
  each had 3/3 accepted smoke samples and `link_up=1`; Slave reported
  `wr_mode=3`. The historical capture does not document the full current
  Step1 error-counter acceptance, so a fresh runtime capture is mandatory.

The local pair under `artifacts/EXP-BASELINE-RS422/` is explicitly not this
candidate: its hashes map to `week02/v01/rs422_uart_diag` in the migration
manifest. It will not be programmed or used as a JTAG milestone.

## Frozen candidate

`candidate_source/` is reconstructed from the historical Git tree above. It
contains the JTAG Quartus project, generated Arria 10 IP, SI5340 controller,
firmware build inputs, and complete vendored dependencies. It applies path
relocations required by the self-contained layout and LF-only line-ending
normalization for cross-platform hashes; hardware logic, firmware logic,
project/revision names, constraints, and pin assignments are not intentionally
changed. See
`analysis/source-relocation.md` and `candidate_source/README.md`.

This remains a candidate, not a milestone PASS. The official
`artifacts/milestones/step1_phy_link/` directory and PASS verdict will only be
created after clean Master/Slave builds, successful programming, and fresh
two-board acceptance validation.

## Required validation

For each board, capture at least:

- PHY ready, RX ready, TX ready, RX lock-to-data
- TM link up and core link OK
- RX encoding / disparity error counters at capture start and end, including
  a sustained window sufficient to identify persistent errors
- stable reset/generation state during observation

The runtime reader must be compatible with the candidate source's actual
JTAG probe manifest. No later-Step image may be substituted.

## Build and program order

Build each role from `candidate_source/scripts/build/build_master.sh` and
`build_slave.sh`. Program using the corresponding scripts under
`candidate_source/scripts/program/`. Historical Step1 procedure programmed
Slave before Master; retain that order unless the fresh build/run evidence
shows that the historical order is not applicable.

All actual build, program, and runtime outputs belong under this experiment's
`raw/build/`, `raw/program/`, and `raw/observe/`. Until those records exist,
the verdict is `CANDIDATE_NOT_VALIDATED`.
