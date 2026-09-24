# Step 2 source audit

## Selection

The selected candidate is exact source commit
`054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`, identified by the historical
`EXP-WRPC-STEP2-DCO-RESTORE-20260819` report. That report documents the
intended Step 2 boundary and a fresh Master/Slave build, program, and runtime
PASS. The report also identifies DCO runtime-start handshake restoration at
`a427ed3f61a54a704c46cf1e0f650ef591f35de1` as the functional change used by
the passing candidate.

The historical Pain directory cited by the report
(`/home/b10504072/04_WR_step2_head`) is absent from the current Pain host, and
its referenced raw program/JTAG captures are not present in the current local
repository. Therefore, the old report is used only to select and interpret
the source. This reproduction will rely on new raw evidence.

## Step-boundary evidence in source and report

The historical Step 2 report defines these role gates:

```text
Master: MODE=2, PTP=6 (PPS_MASTER)
Slave:  MODE=3, PTP=9 (PPS_SLAVE)
Slave foreign metadata: count=1, best_index=0
Both: unique endpoint identity, healthy link, MiniNIC and PTP RX/TX activity
```

The exact source commit contains role-specific firmware defconfigs:

```text
CONFIG_INIT_COMMAND="vlan off;ptp stop;mode master;ptp start"
CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
CONFIG_STEP2_DISABLE_PERSISTENT_INIT=y
```

The source-history diff from the prior Step 1 candidate commit
`b8d4c3d0526f0c2ca282600ef06648dd9f0af595` covers nine functional-source
files (348 insertions, 32 deletions), including the 625 MHz system clock,
role-specific top-level integration, and DCO request-handshake implementation.
These are part of the selected Step 2 checkpoint, not edits made during this
reproduction.

The historical project retains the JTAG top-level entities
`DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`. Its Master/Slave QSF files
reference the corresponding candidate-local HDL, vendored WR cores, generated
Arria-10 PHY IP, and SI5340 controller. The complete assigned-file resolution
audit is recorded after path relocation; independent Quartus clean builds are
required to confirm closure.

After relocation, the automated QSF audit found 554 direct file assignments
(Master 277, Slave 277: 496 VHDL, 50 Verilog, 6 QIP, and 2 SDC), with zero
unresolved paths. Both QSF top-level entity declarations match the historical
JTAG project names. The 3,142-entry source manifest SHA-256 is
`ef623b821a089742a5bcadd5886e257d64ce8cef1368feefaa29fb3c4f3d70dc`.

## Source changes made for a self-contained milestone

The candidate preserves the historical hardware/firmware functional source.
Only packaging/path corrections and build/program wrappers were changed:

1. Flatten the JTAG Quartus project to `quartus/`.
2. Place generated IP at `quartus_generated/` and SI5340 HDL under
   `quartus/si5340_controller/`.
3. Rewrite only the QSF/VHDL paths needed by those moves and the candidate
   build-local firmware MIFs.
4. Replace duplicate historical build/program entry points with one
   `build_master`, `build_slave`, `program_master`, and `program_slave` JTAG
   interface. No RS422 Quartus project or RS422 build/program entry point is
   included in this candidate.
5. Normalize 1,118 auto-detected text files to LF (400,401 CR bytes removed)
   and pin text files to LF in the candidate `.gitattributes`; binary formats
   remain protected. This keeps source-manifest hashes stable across Windows
   and Pain/Linux checkouts.

No Step 2 hardware acceptance has yet been claimed in this audit. The final
experiment report will include path audit counts, clean build provenance,
fresh SOF/MIF hashes, programmer output, and runtime acceptance results.
