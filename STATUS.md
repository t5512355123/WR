# Current status

- Branch: feat/file_cleanup.
- Canonical implementation: the two DE5a JTAG projects, with QSFP-A lane 0 as the fixed White Rabbit link.
- Step 1 PHY/link: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 2 Endpoint/MiniNIC/PTP: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 3 WR parent/signaling handshake: PASS, independently rebuilt, programmed, and runtime-validated; see its report for reset-observability limits.
- Step 4 SoftPLL startup: PASS, independently rebuilt, programmed, and runtime-validated; Master Step 4A and Slave Step 4B event paths passed.
- Step 5 SoftPLL full lock: PASS, independently rebuilt and programmed; Helper/HPLL, Main frequency, Main phase, and PSTAT locks held for a 300291 ms fresh-data span within a 301253 ms session.
- Step 6 historical Global Time and dual-board scheduled digital trigger scope: PASS, independently rebuilt and programmed from its frozen source. Five common PPS labels matched exactly; two repeated scheduled triggers fired at matching TAI/cycle labels on both boards.
- Step 6 pointwise functional gate: **PASS**. The latest dashboard-equivalent read-only 300-second capture had valid/stable Global Time, all eight dashboard Step 1 status bits, and all five Slave lock signals high in 958/958 rows. Two consecutive sampled rows (#91–92, 296 ms apart) had `CKO=+59 ps`, matching TAI/cycles and UCNT; this meets the strict pointwise `abs(CKO) < 60 ps` criterion. Only 2/958 rows were in range, so 300-second phase-offset stability is **NOT ESTABLISHED**. See the [dashboard-equivalent gate report](experiments/step6/EXP-S6-DASHBOARD-EQUIVALENT-GATE-CAPTURE-20260930/REPORT.md). Earlier microtrace and servo-correlation reports remain historical diagnostics, not grounds to infer controller causality.
- Earlier Step 6 correlation (2026-09-30; superseded for current pointwise acceptance): 3,763/3,763 accepted rows over 300,032 ms; 140 CKO transition brackets ≥120 ps, with 96 showing both UCNT and corrected DMS changes. Only 7 rows were strictly inside ±60 ps at both boundaries. Pre/post offsets were +447 ps and -3801 ps. This sequential-read correlation remains non-causal; see the [correlation report](experiments/step6/EXP-S6-SERVO-OFFSET-UPDATE-CORRELATION-20260929/REPORT.md).
- Earlier Step 6 paired-context capture (2026-09-30): valid Global Time and all five Slave lock fields appeared in 958/958 rows; 4/855 UCNT-joined rows met the offset threshold. The follow-on dashboard-equivalent capture above adds explicit Step 1 status gating and is the acceptance evidence for pointwise PASS. See the [paired-context report](experiments/step6/EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/REPORT.md).
- Earlier one-shot live dashboard check (2026-09-30): both boards had valid/stable time and the Slave's five lock bits high, but the instantaneous offset was −3779 ps, so that particular sample was correctly not qualified. It is superseded for current milestone status by the later pointwise capture, not contradicted. See the [dashboard report](experiments/step6/EXP-S6-CURRENT-DASHBOARD-GATE-20260930/REPORT.md).
- Step 6 physical SMA/output edge-skew measurement: NOT EVALUATED. The guarded cached QSFP calibration CLI query was inconclusive because its shell-idle precondition did not pass; no command was sent.

Step 5 timing closure remains NO and is not a functional gate. Its F4L raw audit documents eight repeated page-2 histogram-accounting warnings and the known sideband diagnostic limitation; no raw rows were dropped.

Current source layout: canonical JTAG projects are flattened under quartus/, generated Quartus inputs are under quartus_generated/, SI5340 RTL is under quartus/si5340_controller/, and tests are consolidated under scripts/tests/. The canonical-path and stale-reference audit is complete.

Step 6's pointwise functional milestone is complete. Any future extension should be separately scoped as sustained phase-offset stability or physical SMA/output-edge-skew measurement; neither is claimed here. No further hardware action is part of this milestone update.
