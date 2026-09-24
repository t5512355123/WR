# Step1 milestone reconstruction — interim report

## Current verdict

```text
STEP1_MILESTONE = NOT_PASS_YET
CANDIDATE_SOURCE_AUDIT = PASS
MASTER_CLEAN_BUILD = NOT_RUN
SLAVE_CLEAN_BUILD = NOT_RUN
MASTER_PROGRAM = NOT_RUN
SLAVE_PROGRAM = NOT_RUN
STEP1_RUNTIME_ACCEPTANCE = NOT_RUN
```

No hardware PASS is claimed. The formal
`artifacts/milestones/step1_phy_link/` checkpoint will not be created until
both candidate images have been rebuilt, programmed, and freshly validated.

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

The candidate retains the original historical build provenance. The local
Python analyzer contract tests pass (5/5). The actual Quartus clean build and
JTAG capture are still pending on Pain.

The reconstructed source snapshot contains 3,118 files in
`candidate_source/SHA256SUMS`; that source-manifest SHA-256 is
`971d863f6171d2f6c496b197f84dc774e2d56d7495f874db2c815f0c00f5a96b`.

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

## Next

Commit/push this isolated Step1 candidate and validation harness, pull it on
Pain, run a clean Master build and a clean Slave build, then save the exact
build logs and SOF hashes. Only after both builds succeed should the candidate
SOFs be programmed Slave then Master and the read-only Step1 capture run.
