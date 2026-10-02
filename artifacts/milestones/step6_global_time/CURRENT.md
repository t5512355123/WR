# Step6 milestone: sampled TIME_VALID for 300 seconds

Frozen publication source: `1c9aea5b381a2be1b578305d1b0c620985bf72eb`.
Actual FPGA compile source: `40c388010fff51991d958f50702f42b3d3437d61`.
Experiment: `EXP-S6-TIME-VALID-300S-MASTER-BOOTSTRAP2048-20261002`.

Master: 1190/1190 valid rows over 302871 ms. Slave: 1190/1190 over
302876 ms. Maximum sample gaps: 256/257 ms. The boards were sampled
sequentially. No claim of uninterrupted cycle-by-cycle validity is made.
Master Helper is still unlocked; fine timestamp accuracy, physical edge
skew and universal startup repeatability are not established. Timing closure
and offset <60 ps are not this revised milestone's gates.

## Reproduce on Pain

Stop any other JTAG dashboard first. Prepare the independent frozen checkout:

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step6_global_time
bash prepare_current.sh
cd current
```

The archive includes all root scripts, firmware, vendor source, RTL, Quartus
projects/generated IP, retained firmware/build products, both qualified SOFs,
the dashboard and qualification evidence. The nested historical source is
retained only as the baseline used by existing source-regression tests.

Run the four original entrypoints, in order:

```sh
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

For the exact already-qualified bitstreams, omit the first two commands.
They are in `current/output/DE5a_wr_master_jtag.sof` and
`current/output/DE5a_wr_slave_jtag.sof`; `program_current.sh` checks their
source/MIF hashes and programs Slave first, then Master.
Recompilation is supported but may produce different SOF bytes; only the
retained bitstreams have the recorded hardware qualification.

After stopping the live dashboard, independently verify a new session:

```sh
bash scripts/monitor/verify_time_valid_300s.sh
```

Reproduction requires Quartus 17.0 at the configured path, the existing RISC-V
toolchain, Git, Bash, Python and access to both DE5a JTAG cables. The archive
does not contain these installed tools or credentials. Its scripts compute
paths relative to this checkout, not the parent root. A local Git index is
created by prepare_current.sh for build/export provenance; original compile
identities are retained in output/ and evidence.

`source/`, `master.sof`, `slave.sof`, `SHA256SUMS` and
`HISTORICAL_README.md` are the previous milestone, preserved unchanged.
Use `current/`, not `source/`, for the new 300-second milestone.
