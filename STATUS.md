# Current status

- Branch: `feat/file_cleanup`.
- Current canonical hardware path: two DE5a boards using the JTAG projects
  `DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`; QSFP-A lane 0 is the fixed
  White Rabbit link. Do not use legacy/non-JTAG projects for current work.
- Step 1 PHY/link: **PASS**, independently clean-built, programmed, and
  runtime-validated from its frozen source.
- Step 2 Endpoint/MiniNIC/PTP: **PASS**, independently clean-built, programmed,
  and runtime-validated from its frozen source.
- Step 3 WR handshake: **NOT REPRODUCED** as an independent frozen milestone.
- Step 4 SoftPLL startup: **NOT REPRODUCED** as an independent frozen
  milestone.
- Step 5 SoftPLL lock: historical 300-second functional evidence exists, but
  its independent frozen-source reproduction is **PENDING**.
- Step 6 Global time / digital scheduled trigger: historical digital evidence
  exists, but its independent frozen-source reproduction is **PENDING**.
- Physical SMA/output edge-skew measurement: **NOT EVALUATED**.

Current next target: Step 3, using its own audited historical JTAG source and
acceptance criteria. Do not substitute a later-Step SOF for an earlier
milestone. See [`MILESTONES.md`](MILESTONES.md) for hashes and evidence paths.

The repository-wide path/documentation cleanup is still in progress. Frozen
sources under `artifacts/milestones/` are for reproduction and comparison, not
for ordinary development. The current canonical JTAG design remains the only
intended implementation; the eventual cleanup will consolidate its source
paths and build/program interface.
