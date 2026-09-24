# Current status

- Branch: `feat/file_cleanup`.
- Canonical hardware path: two DE5a boards using the JTAG projects
  `DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`; QSFP-A lane 0 is the fixed
  White Rabbit link. Legacy/non-JTAG projects are not current development paths.
- Step 1 PHY/link: **PASS**, independently rebuilt, programmed, and runtime-
  validated from frozen source.
- Step 2 Endpoint/MiniNIC/PTP: **PASS**, independently rebuilt, programmed,
  and runtime-validated from frozen source.
- Step 3 WR handshake: **PASS**, independently rebuilt, programmed, and
  runtime-validated from frozen source. See its experiment report for reset
  observability limitations.
- Step 4 SoftPLL startup: **PASS**, independently rebuilt from frozen source,
  programmed on both boards, and runtime-validated. Master Step 4A and Slave
  Step 4B event processing passed. Timing closure is not claimed.
- Step 5 SoftPLL lock: independent frozen-source reproduction **PENDING**;
  historical 300-second functional evidence exists.
- Step 6 Global time / digital scheduled trigger: independent frozen-source
  reproduction **PENDING**; physical SMA/output edge skew is **NOT EVALUATED**.

Current source layout: canonical JTAG projects are flattened under `quartus/`,
generated Quartus inputs are under `quartus_generated/`, SI5340 RTL is under
`quartus/si5340_controller/`, and tests are consolidated under
`scripts/tests/`. Historical experiment/document migration and the full stale-
reference audit remain in progress.

Next target: complete remaining repository cleanup and stale-reference
validation, then independently reproduce Step 5 from its own frozen source.
Do not substitute a later-Step SOF for an earlier milestone. See
[`MILESTONES.md`](MILESTONES.md) for hashes and evidence paths.
