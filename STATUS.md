# Current status

- Branch: feat/file_cleanup.
- Canonical implementation: the two DE5a JTAG projects, with QSFP-A lane 0 as the fixed White Rabbit link.
- Step 1 PHY/link: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 2 Endpoint/MiniNIC/PTP: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 3 WR parent/signaling handshake: PASS, independently rebuilt, programmed, and runtime-validated; see its report for reset-observability limits.
- Step 4 SoftPLL startup: PASS, independently rebuilt, programmed, and runtime-validated; Master Step 4A and Slave Step 4B event paths passed.
- Step 5 SoftPLL full lock: PASS, independently rebuilt and programmed; Helper/HPLL, Main frequency, Main phase, and PSTAT locks held for a 300291 ms fresh-data span within a 301253 ms session.
- Step 6 historical Global Time and dual-board scheduled digital trigger scope: PASS, independently rebuilt and programmed from its frozen source. Five common PPS labels matched exactly; two repeated scheduled triggers fired at matching TAI/cycle labels on both boards.
- Step 6 current expanded acceptance: NOT ESTABLISHED. On the exact frozen Step 6 images, the dashboard re-observation captured one valid/stable Slave sample at -17 ps in `TRACK_PHASE`, followed 10 seconds later by +1165 ps in `WAIT_OFFSET_STABLE`. A subsequent high-rate frozen-reader capture produced 0/60 strict `<60 ps` samples and showed 55 `WAIT_OFFSET_STABLE` plus 5 `SYNC_PHASE` rows, with all five Step 5 lock signals high in 60/60 rows. See the [exact-image report](experiments/step6/EXP-S6-FROZEN-IMAGE-STRICT-PHASE-300S-20260929/REPORT.md) and [high-rate correlation report](experiments/step6/EXP-S6-SERVO-TRANSITION-HIGH-RATE-CORRELATION-20260929/REPORT.md). The separate half-gain run observed -539 ps and is not the frozen milestone image.
- Step 6 physical SMA/output edge-skew measurement: NOT EVALUATED. The guarded cached QSFP calibration CLI query was inconclusive because its shell-idle precondition did not pass; no command was sent.

Step 5 timing closure remains NO and is not a functional gate. Its F4L raw audit documents eight repeated page-2 histogram-accounting warnings and the known sideband diagnostic limitation; no raw rows were dropped.

Current source layout: canonical JTAG projects are flattened under quartus/, generated Quartus inputs are under quartus_generated/, SI5340 RTL is under quartus/si5340_controller/, and tests are consolidated under scripts/tests/. The canonical-path and stale-reference audit is complete.

Next target: add a bounded read-only fast reader for the source-audited SSTAT/CKO and lock/validity words; the 60-row capture still sampled at a 579 ms median and did not capture `TRACK_PHASE`. Do not adjust the frozen image, servo threshold, gains, timing constraints, or clock settings until finer transition evidence supports a specific cause. Preserve the separate physical SMA/output-edge-skew caveat. Do not use a later Step image to satisfy an earlier milestone. See MILESTONES.md for checkpoint hashes and evidence.
