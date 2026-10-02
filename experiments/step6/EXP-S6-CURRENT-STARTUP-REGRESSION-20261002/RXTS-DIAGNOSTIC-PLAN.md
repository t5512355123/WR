# Passive RXTS calibration diagnostic

Goal: identify the acquisition failure before changing a controller. This is
not a Step6 PASS candidate or a new acceptance threshold.

Baseline: current /2 acquisition + /12 tracking, source `8acee56a` before the
passive firmware addition; the failing fresh SOFs are identified in REPORT.md.

Only firmware change: explicit `pll stat` additionally prints active T24P,
phase-tracker readback/readiness and calibration scan phase/detector state.
The scan values are not a success flag. Queries are non-atomic and are not
packet-level timestamp correlations. The observer sends only `pll stat` and
`pll gps 0`; it does not invoke `calibration`, `pll sps` or a reset.

19 offline source/observer tests passed. They verify that the original
calibrator implementation outside the diagnostic function and the existing
servo/HDL baseline remain unchanged, and that no phase or storage writes occur
in the diagnostic function. Compile with warnings-as-errors on Pain still
must pass; source tests do not substitute for compilation.

The initial bounded RAM query found that CONFIG_CMD_LL is disabled in the
programmed firmware. All replies were "Unrecognized command devmem"; they are
not RAM values. No CPU reset or host instruction-port access was used to get
around this restriction.

The existing `pll stat`/`pll gps 0` query succeeded, with reset/generation
unchanged: SoftPLL mode3/ready, HL1/ML1, DelCnt0, ptracker enabled with n_avg512.
This alone does not prove timestamp calibration is correct. Exact command
captures remain on Pain pending evidence transfer.

Before rebuilding, the user's failing generated outputs and firmware were
preserved in `/tmp/wr-pre-rxts-diagnostic-20261002.tgz` on Pain, SHA-256
`1a2478cb2379b2ef3e9efdc82361d9326198e823c62fb47385feaf5a3e3aba3e`.
The protected archive was not used or changed.

The passive firmware change necessarily changes MIF hashes. The first current
build correctly rejected the old frozen hashes after both firmware compiles
succeeded. Update the pinned hashes to the diagnostic build, document that
change, then repeat the four root script steps. Do not bypass a failed hash
check and do not present the previous successful artifacts as this new build.

Pinned diagnostic MIF hashes (source firmware addition `8ce559db`): Master
`18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea`, Slave
`91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379`.
The current experiment identifier now refers to this diagnostic, not to the
earlier passing run. Firmware version metadata stays pinned as before.

Both firmware builds then passed the pinned checks under the root
`build_current.sh` workflow. Logs are retained in this experiment's `raw/`
folder. FPGA compilation was started on Pain at source `9fe20c3e`, using
`scripts/build/compile_current.sh`; this is a progress record, not a claim of
new SOF/programming/runtime acceptance. Precompile query and firmware logs
were copied to Laptop with transfer archive SHA-256
`1f6f529372b7b58d819fe919bce80fe0e9debb2c9ed281ad7ae3059db2f996da`.

Stop on failed build/program, image mismatch, conflicting reader, invalid
transport, reset/generation change or persistent invalid query replies.
After entry gates establish, collect the explicit RXTS readback and a short
UCNT-guarded phase-context capture. Decide the next repair from those results;
do not automatically retune gains, widen validity gates or force TIME_VALID.
