# Step1 milestone reconstruction — final report

## Current verdict

```text
STEP1_MILESTONE = PASS
CANDIDATE_SOURCE_AUDIT = PASS
MASTER_CLEAN_BUILD = PASS
SLAVE_CLEAN_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_RUNTIME_ACCEPTANCE = PASS
```

The formal checkpoint is frozen at
`artifacts/milestones/step1_phy_link/`. Its README records source provenance,
build/program details, acceptance results, and limitations.

## Candidate selection

The selected historical JTAG candidate is source commit
`b8d4c3d0526f0c2ca282600ef06648dd9f0af595`, identified by the 2026-08-17
`EXP-WRPC-BASELINE-RESTORE-20260817` report. That report records Quartus Prime
17.0.0 Build 595, successful Master and Slave JTAG programming, 3/3 accepted
smoke frames per board, and `link_up=1` on both boards. It is historical
selection evidence only; the current Step1 acceptance still requires a fresh
build, program, and runtime capture.

The SOFs currently in `artifacts/EXP-BASELINE-RS422/` were rejected as a
candidate. Their hashes match the migration inventory entries under
`week02/v01/rs422_uart_diag/`, not the JTAG images in the 2026-08-17 report.

## Frozen candidate source audit

The candidate snapshot was extracted from the selected commit and placed at:

```text
candidate_source/
```

It contains 3,107 historical source files (53,861,987 bytes before adding the
Step1 runner/build wrappers), including the JTAG projects, all six generated
IP QIPs and their source, SI5340 controller RTL, firmware inputs, and vendored
WR cores/WRPC software. No Git submodules or symlink entries were found in
these selected historical trees.

Path-only relocation was applied to the candidate QSF/VHDL files to match the
self-contained source layout. The independent path audit found 552 file
assignments in total: 494 VHDL, 50 Verilog, 6 QIP, and 2 SDC assignments; all
resolved to existing files. No stale `../../vendor`, `../../generated`,
`../../rtl`, or `../../build` roots remain in the flattened projects. The
historical top-level entities remain `DE5a_wr_master_jtag` and
`DE5a_wr_slave_jtag`.

For portable source hashes, 1,098 CRLF text files were normalized to LF; no
other bytes were changed by that normalization. Candidate `.gitattributes`
keeps text checkouts stable, and the manifest excludes itself, ignored build
outputs, and Python bytecode caches.

The local analyzer contract tests pass (5/5). Pain verified all 3,118 source
manifest entries before building. The copied frozen milestone source was
verified again on Laptop with 0 hash errors.

The reconstructed source snapshot contains 3,118 files in
`candidate_source/SHA256SUMS`; that source-manifest SHA-256 is
`971d863f6171d2f6c496b197f84dc774e2d56d7495f874db2c815f0c00f5a96b`.

## Build and programming results

Build host: Pain, repository commit
`0d21ae848f4e767dffc487ed0b318768f63bc1d8`. Quartus Prime was 17.0.0 Build
595 Standard Edition; firmware tools were `riscv64-unknown-elf-gcc` 9.3.0 and
GNU ld 2.34. Master started from an empty candidate Quartus database. Before
Slave compilation, Quartus `--clean -c DE5a_wr_slave_jtag` cleaned the Slave
revision so its result did not reuse stale revision data.

| Role | Full compile | Errors / warnings | Rebuilt SOF SHA-256 | Rebuilt MIF SHA-256 |
|---|---|---:|---|---|
| Master | PASS | 0 / 267 | `f2e2136e8159ba9135313536f1a641c0865dbf36f267e06ef7826e0363f8c07e` | `1748846b04070b25a391fbc31fbbbb4a1fb9a91b8d71a0505c443fdd02ce1e1e` |
| Slave | PASS | 0 / 267 | `15997ca2dd2ea2597d7f25af5522afc0144219769450824c0a7e31526cd44112` | `480e5c80b08ecd0bb719a371154be6aa2521f2d09f228e2cf7430270bf20619e` |

The rebuilt firmware MIF hashes differ from the historical MIF hashes recorded
in `PLAN.md`; this is disclosed, not treated as bit-identical provenance. The
newly built SOFs above are exactly the ones programmed and runtime-validated.

Programming followed Slave then Master. Slave on `DE5 [1-11.2]` and Master on
`DE5 [1-11.1]` each reported configuration succeeded with 0 errors and 0
warnings. JTAG enumeration identified both as DE5a 10AX115H devices.

## Step1 acceptance contract

The historical instance-0 64-bit probe directly exposes the required status
bits. A new read-only Tcl runner captures 360 samples at a requested 100 ms
gap, preserving the raw word. Its offline decoder requires each board to have
at least 300 contiguous samples spanning 30 seconds, with `wr_ready`, RX/TX
ready, TM link, core link, CPU reset released, and RX locked-to-data asserted
for every sample. Encoding-error indicators are checked across the same
window; five consecutive error-bearing samples with adjacent sample gaps no
greater than 250 ms fail the no-persistent-error gate. Any read failure,
missing role, extra board, malformed row, or incomplete window is
INCONCLUSIVE, not PASS.

## Fresh runtime acceptance

The read-only instance-0 capture contains 720 valid sample rows: 360 per board,
each contiguous and spanning over 36 seconds. There were 0 malformed rows and
0 read failures.

| Gate | Master drops | Slave drops |
|---|---:|---:|
| PHY ready (`wr_ready`) | 0 | 0 |
| RX ready / TX ready | 0 / 0 | 0 / 0 |
| TM link up / core link OK | 0 / 0 | 0 / 0 |
| CPU reset released / RX locked to data | 0 / 0 | 0 / 0 |
| Encoding/disparity error samples | 0 | 0 |
| Maximum consecutive error samples | 0 | 0 |

Analyzer output: `STEP1_OVERALL=PASS`. Thus both boards satisfied the Step1
PHY/link acceptance for the complete observation window.

## Evidence

- Build and toolchain logs: `raw/build/`
- Programming logs: `raw/program/`
- Raw JTAG capture and decoder output: `raw/observe/`
- Official frozen source and programmed SOFs:
  `artifacts/milestones/step1_phy_link/`

The legacy Step1 probe samples `CPU_RESET_n` but does not expose a separate boot
generation counter; reset remained released in every captured sample. Timing
closure is not claimed or required for Step1. Endpoint/PTP, WR handshake,
SoftPLL, lock, and global time remain outside this milestone.
