# Current status

- Branch: feat/file_cleanup.
- Canonical implementation: the two DE5a JTAG projects, with QSFP-A lane 0 as the fixed White Rabbit link.
- Step 1 PHY/link: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 2 Endpoint/MiniNIC/PTP: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 3 WR parent/signaling handshake: PASS, independently rebuilt, programmed, and runtime-validated; see its report for reset-observability limits.
- Step 4 SoftPLL startup: PASS, independently rebuilt, programmed, and runtime-validated; Master Step 4A and Slave Step 4B event paths passed.
- Step 5 SoftPLL full lock: PASS, independently rebuilt and programmed; Helper/HPLL, Main frequency, Main phase, and PSTAT locks held for a 300291 ms fresh-data span within a 301253 ms session.
- Step 6 historical Global Time and dual-board scheduled digital trigger scope: PASS, independently rebuilt and programmed from its frozen source. Five common PPS labels matched exactly; two repeated scheduled triggers fired at matching TAI/cycle labels on both boards.
- Step 6 current expanded acceptance: NOT ESTABLISHED. The Slave must additionally show a valid/stable Global-Time snapshot with `abs(WR_SERVO_OFFSET_PS) < 60`. The 2026-09-27 frozen-image report predates this gate; the 2026-09-29 half-gain run observed -539 ps and did not pass it.
- Step 6 physical SMA/output edge-skew measurement: NOT EVALUATED. The guarded cached QSFP calibration CLI query was inconclusive because its shell-idle precondition did not pass; no command was sent.

Step 5 timing closure remains NO and is not a functional gate. Its F4L raw audit documents eight repeated page-2 histogram-accounting warnings and the known sideband diagnostic limitation; no raw rows were dropped.

Current source layout: canonical JTAG projects are flattened under quartus/, generated Quartus inputs are under quartus_generated/, SI5340 RTL is under quartus/si5340_controller/, and tests are consolidated under scripts/tests/. The canonical-path and stale-reference audit is complete.

Next target: run the strict `<60 ps` Slave offset gate on the exact frozen Step 6 image and record a valid/stable sample; preserve the separate physical SMA/output-edge-skew caveat. Do not use a later Step image to satisfy an earlier milestone. See MILESTONES.md for checkpoint hashes and evidence.
