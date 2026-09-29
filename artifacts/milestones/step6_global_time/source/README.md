# Frozen Step 6 reproduction source — historical digital scope validated

This frozen package independently reproduced the historical Step 6 digital
functional scope on 2026-09-27: valid Global Time, matching same-PPS labels,
and repeated dual-board scheduled digital triggers. See
`experiments/step6/EXP-S6-MILESTONE-REPRO-20260927/REPORT.md`.

The current expanded Step 6 acceptance is **NOT ESTABLISHED**: the Slave must
also show a valid/stable Global-Time snapshot with
`abs(WR_SERVO_OFFSET_PS) < 60`. The frozen-image retrospective values were
`-158 ps` and `+135 ps`, so neither met that criterion. Do not describe this
historical digital-scope result as a pass of the expanded gate.

Hardware and firmware source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.

Read-only Step 1–6 dashboard overlay: `3b3a8ec52668d0c60550451ef1780539f7c93fd7`. It consists only of
the host monitor, JTAG reader, and offline dashboard test; it does not change
RTL, firmware control, or the FPGA image.

Historical Quartus/generated/source paths are relocated into the current
canonical layout. The only source transformations are the QSF relative-path
and top-level firmware-MIF path relocations recorded per file in
`SOURCE_MANIFEST.tsv`.

The 2026-09-27 reproduction carries a narrowly scoped firmware change and
observer overlay in `vendor/wrpc-sw/dev/sfp.c` and
`vendor/wrpc-sw/shell/cmd_sfp.c`. Startup matching retains SFF-8472 handling
for SFP identifier `0x03`; QSFP+ / QSFP28 identifiers `0x0D` / `0x11` use the
SFF-8636 Upper Page 00h serial-ID fields. The QSFP path requires page select
00h, validates CC_BASE and CC_EXT at the standard offsets, then looks up the
actual 16-byte module part number in the existing calibration database. It
does not write the module page selector, EEPROM, or SDBFS. Database misses and
I2C/checksum errors do not load guessed calibration values.

`sfp params` reports the active calibration and cached identifier. The
explicit `sfp params live` query reads the lower page, page-select byte, and
Upper Page 00h into local buffers; it reports ACKs, raw bytes, checksums, and a
read-only local-copy database lookup. It does not call `sfp_match()` or modify
active calibration. This firmware change does not adjust PLL/PTP control
parameters and is not by itself proof of either Step 6 acceptance scope; every
overlay is identified in `SOURCE_MANIFEST.tsv`.

Build on Pain from this directory using Quartus Prime Standard 17.0 and the
configured RISC-V toolchain:

```sh
bash scripts/build/build_firmware.sh master
bash scripts/build/build_master.sh
bash scripts/build/build_firmware.sh slave
bash scripts/build/build_slave.sh
```

The resulting SOFs are `quartus/output_files_master_jtag/DE5a_wr_master_jtag.sof`
and `quartus/output_files_slave_jtag/DE5a_wr_slave_jtag.sof`. Program the
reproduction images Slave then Master. `SOURCE_MANIFEST.tsv` ties every
historical blob and tooling overlay to its packaged SHA-256.

The historical digital-scope milestone was independently clean-built,
programmed, and validated against the dashboard, 300-second Step 5 lock,
Step 6A same-PPS consistency, and Step 6B scheduled digital-trigger criteria.
The expanded `<60 ps` Slave offset gate remains pending a qualifying
valid/stable hardware observation.
