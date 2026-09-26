# Frozen Step 6 source candidate

Hardware and firmware source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.

Read-only Step 1–6 dashboard overlay: `3b3a8ec52668d0c60550451ef1780539f7c93fd7`. It consists only of
the host monitor, JTAG reader, and offline dashboard test; it does not change
RTL, firmware control, or the FPGA image.

Historical Quartus/generated/source paths are relocated into the current
canonical layout. The only source transformations are the QSF relative-path
and top-level firmware-MIF path relocations recorded per file in
`SOURCE_MANIFEST.tsv`. No functional source edits are made by this packager.

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

The candidate becomes a Step 6 milestone only after independent clean builds,
hardware programming, dashboard validation, the 300-second Step 5 lock check,
Step 6A same-PPS consistency, and Step 6B scheduled digital-trigger validation.
