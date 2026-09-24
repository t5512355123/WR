# Current status

- Branch: feat/file_cleanup.
- Canonical implementation: the two DE5a JTAG projects, with QSFP-A lane 0 as the fixed White Rabbit link.
- Step 1 PHY/link: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 2 Endpoint/MiniNIC/PTP: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 3 WR parent/signaling handshake: PASS, independently rebuilt, programmed, and runtime-validated; see its report for reset-observability limits.
- Step 4 SoftPLL startup: PASS, independently rebuilt, programmed, and runtime-validated; Master Step 4A and Slave Step 4B event paths passed.
- Step 5 SoftPLL full lock: PASS, independently rebuilt and programmed; Helper/HPLL, Main frequency, Main phase, and PSTAT locks held for a 300291 ms fresh-data span within a 301253 ms session.
- Step 6 Global time and dual-board scheduled trigger: independent frozen-source reproduction PENDING.
- Step 6 physical SMA/output edge-skew measurement: NOT EVALUATED.

Step 5 timing closure remains NO and is not a functional gate. Its F4L raw audit documents eight repeated page-2 histogram-accounting warnings and the known sideband diagnostic limitation; no raw rows were dropped.

Current source layout: canonical JTAG projects are flattened under quartus/, generated Quartus inputs are under quartus_generated/, SI5340 RTL is under quartus/si5340_controller/, and tests are consolidated under scripts/tests/. The canonical-path and stale-reference audit is complete.

Next target: independently reproduce Step 6 from its own frozen source. Do not use a later Step image to satisfy an earlier milestone. See MILESTONES.md for checkpoint hashes and evidence.
