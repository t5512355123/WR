# Current status

- Branch: feat/file_cleanup.
- Canonical implementation: the two DE5a JTAG projects, with QSFP-A lane 0 as the fixed White Rabbit link.
- Step 1 PHY/link: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 2 Endpoint/MiniNIC/PTP: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 3 WR parent/signaling handshake: PASS, independently rebuilt, programmed, and runtime-validated; see its report for reset-observability limits.
- Step 4 SoftPLL startup: PASS, independently rebuilt, programmed, and runtime-validated; Master Step 4A and Slave Step 4B event paths passed.
- Step 5 SoftPLL full lock: PASS, independently rebuilt and programmed; Helper/HPLL, Main frequency, Main phase, and PSTAT locks held for a 300291 ms fresh-data span within a 301253 ms session.
- Step 6 historical Global Time and dual-board scheduled digital trigger scope: PASS, independently rebuilt and programmed from its frozen source. Five common PPS labels matched exactly; two repeated scheduled triggers fired at matching TAI/cycle labels on both boards.
- Step 6 current expanded acceptance: NOT ESTABLISHED. On the exact frozen Step 6 images, the 2026-09-29 re-observation produced one valid/stable Slave sample at -17 ps in `TRACK_PHASE`; the next 10-second sample was +1165 ps in `WAIT_OFFSET_STABLE`. Only 1/105 valid/stable Slave time samples was strictly inside (-60,+60) ps, so no stable interval was established. See [the exact-image re-observation report](experiments/step6/EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/REPORT.md). The separate half-gain run observed -539 ps and is not the frozen milestone image.
- Step 6 physical SMA/output edge-skew measurement: NOT EVALUATED. The guarded cached QSFP calibration CLI query was inconclusive because its shell-idle precondition did not pass; no command was sent.

Step 5 timing closure remains NO and is not a functional gate. Its F4L raw audit documents eight repeated page-2 histogram-accounting warnings and the known sideband diagnostic limitation; no raw rows were dropped.

Current source layout: canonical JTAG projects are flattened under quartus/, generated Quartus inputs are under quartus_generated/, SI5340 RTL is under quartus/si5340_controller/, and tests are consolidated under scripts/tests/. The canonical-path and stale-reference audit is complete.

Next target: execute the bounded read-only high-rate capture in [the Step 6 servo-transition plan](experiments/step6/EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/PLAN.md) to resolve why the observed brief `TRACK_PHASE` entry returned to acquisition. Do not adjust the frozen image, servo threshold, gains, timing constraints, or clock settings until the transition trace supports a specific cause. Preserve the separate physical SMA/output-edge-skew caveat. Do not use a later Step image to satisfy an earlier milestone. See MILESTONES.md for checkpoint hashes and evidence.
