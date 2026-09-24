# Current status

- Branch: `feat/file_cleanup`.
- Current canonical hardware path: two DE5a boards using the JTAG projects
  `DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`; QSFP-A lane 0 is the fixed
  White Rabbit link. Do not use legacy/non-JTAG projects for current work.
- Step 1 PHY/link: **PASS**, independently clean-built, programmed, and
  runtime-validated from its frozen source.
- Step 2 Endpoint/MiniNIC/PTP: **PASS**, independently clean-built, programmed,
  and runtime-validated from its frozen source.
- Step 3 WR handshake: **PASS**, independently clean-built and programmed on
  both boards. Stable 30-sample observations passed Step 1/2 prerequisite and
  Step 3 WR parent/signaling checks. This does not claim SoftPLL lock or valid
  global time. No source-backed reset-generation counter is exposed; see the
  report for the sampled reset observability limit.
- Step 4 SoftPLL startup: **NOT REPRODUCED** as an independent frozen
  milestone.
- Step 5 SoftPLL lock: historical 300-second functional evidence exists, but
  its independent frozen-source reproduction is **PENDING**.
- Step 6 Global time / digital scheduled trigger: historical digital evidence
  exists, but its independent frozen-source reproduction is **PENDING**.
- Physical SMA/output edge-skew measurement: **NOT EVALUATED**.

Current source layout: canonical JTAG projects are flattened under `quartus/`,
generated Quartus inputs are under `quartus_generated/`, SI5340 RTL is under
`quartus/si5340_controller/`, and tests are consolidated under
`scripts/tests/`. Historical experiment/document migration and the full stale-
reference audit remain in progress.

Next target: finish repository correctness and verify a clean build of the
canonical JTAG source, then independently reproduce Step 4 using its own
frozen source and acceptance criteria. Do not substitute a later-Step SOF for
an earlier milestone. See [`MILESTONES.md`](MILESTONES.md) for hashes and
evidence paths.
