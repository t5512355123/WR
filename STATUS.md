# Current status

2026-10-02 current qualification: **PASS_TIME_VALID_300S on both boards**.
Master 1190/1190 rows over 302871 ms; Slave 1190/1190 over 302876 ms,
max gaps 256/257 ms, no invalid rows or transport errors. Current SOFs are
freshly compiled/programmed from 40c38801 and retained in output/.
Master Helper remains unlocked/unready; fine timestamp correctness and
universal startup repeatability are NOT ESTABLISHED. This PASS is strictly
the user's revised sampled TIME_VALID-only gate, not a Helper repair.

- Branch: feat/file_cleanup.
- Latest session (2026-10-02): both TIME_VALID/PPS_VALID bits stayed 1 in all 1190 sampled rows per board, and the post-capture dashboard remained valid. See the [current qualification report](experiments/step6/EXP-S6-TIME-VALID-300S-MASTER-BOOTSTRAP2048-20261002/REPORT.md). Earlier WAITING sessions and their [regression evidence](experiments/step6/EXP-S6-CURRENT-STARTUP-REGRESSION-20261002/REPORT.md) remain historical evidence, not the present runtime verdict.
- Current root workflow revalidated 2026-10-02: acquisition `/2`, tracking `/12`, no temporary source checkout. Fresh firmware matched the proven MIFs exactly; both root FPGA builds and Slave→Master programming passed. Master/Slave TIME_VALID were 1190/1190 valid samples across 302868/302813 ms, max gap 257 ms each. Current images and full compile reports are retained in `output/`, firmware products in `build/`; see the [root revalidation report](experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/ROOT-WORKFLOW-REVALIDATION-20261002.md).
- Canonical implementation: the two DE5a JTAG projects, with QSFP-A lane 0 as the fixed White Rabbit link.
- Step 1 PHY/link: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 2 Endpoint/MiniNIC/PTP: PASS, independently rebuilt, programmed, and runtime-validated.
- Step 3 WR parent/signaling handshake: PASS, independently rebuilt, programmed, and runtime-validated; see its report for reset-observability limits.
- Step 4 SoftPLL startup: PASS, independently rebuilt, programmed, and runtime-validated; Master Step 4A and Slave Step 4B event paths passed.
- Step 5 SoftPLL full lock: PASS, independently rebuilt and programmed; Helper/HPLL, Main frequency, Main phase, and PSTAT locks held for a 300291 ms fresh-data span within a 301253 ms session.
- Step 6 historical Global Time and dual-board scheduled digital trigger scope: PASS, independently rebuilt and programmed from its frozen source. Five common PPS labels matched exactly; two repeated scheduled triggers fired at matching TAI/cycle labels on both boards.
- Revised Step 6 target (2026-10-01): **PASS — two independent fresh same-source build/program runs each held exported `STATUS_TIME_VALID` in every sampled row for >300 s on both boards**. Run 1: Master/Slave 1190/1190 rows, spans 302,887/302,880 ms, maximum gaps 257/257 ms. Run 2: 1190/1190 each, spans 302,879/302,870 ms, maximum gaps 256/257 ms. Both runs used `/2 acquisition + /12 tracking`; the boards were observed sequentially at a requested 250 ms interval. This supports repeatability of the sampled-bit criterion, not cycle-by-cycle continuity between reads. The historical SOF binaries were unavailable, so the freshly generated images are not claimed byte-identical to those old files. Timing closure, Step 5 locks, phase offset, and physical SMA edge skew are not gates for this target. See the [300-second repeat report](experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/REPORT.md) and [experiment plan](experiments/step6/EXP-S6-TIME-VALID-300S-REPEAT-ACQ2-TRACK12-20261001/PLAN.md). Historical near-pass data and earlier pointwise `abs(CKO)<60 ps` evidence remain detailed in those reports.
- Earlier Step 6 correlation (2026-09-30; superseded for current pointwise acceptance): 3,763/3,763 accepted rows over 300,032 ms; 140 CKO transition brackets ≥120 ps, with 96 showing both UCNT and corrected DMS changes. Only 7 rows were strictly inside ±60 ps at both boundaries. Pre/post offsets were +447 ps and -3801 ps. This sequential-read correlation remains non-causal; see the [correlation report](experiments/step6/EXP-S6-SERVO-OFFSET-UPDATE-CORRELATION-20260929/REPORT.md).
- Earlier Step 6 paired-context capture (2026-09-30): valid Global Time and all five Slave lock fields appeared in 958/958 rows; 4/855 UCNT-joined rows met the offset threshold. The follow-on dashboard-equivalent capture above adds explicit Step 1 status gating and is the acceptance evidence for pointwise PASS. See the [paired-context report](experiments/step6/EXP-S6-WRH-SERVO-PHASE-CONTEXT-UCNT-PAIR-20260930/REPORT.md).
- Earlier one-shot live dashboard check (2026-09-30): both boards had valid/stable time and the Slave's five lock bits high, but the instantaneous offset was −3779 ps, so that particular sample was correctly not qualified. It is superseded for current milestone status by the later pointwise capture, not contradicted. See the [dashboard report](experiments/step6/EXP-S6-CURRENT-DASHBOARD-GATE-20260930/REPORT.md).
- Step 6 physical SMA/output edge-skew measurement: NOT EVALUATED. The guarded cached QSFP calibration CLI query was inconclusive because its shell-idle precondition did not pass; no command was sent.

Step 5 timing closure remains NO and is not a functional gate. Its F4L raw audit documents eight repeated page-2 histogram-accounting warnings and the known sideband diagnostic limitation; no raw rows were dropped.

Current source layout: canonical JTAG projects are flattened under quartus/, generated Quartus inputs are under quartus_generated/, SI5340 RTL is under quartus/si5340_controller/, and tests are consolidated under scripts/tests/. The canonical-path and stale-reference audit is complete.

The historical Step 6 pointwise milestone and recorded 300-second captures remain complete under their recorded scopes. The later startup failure means the current workflow cannot yet be claimed reliably repaired. Physical SMA/output-edge-skew measurement remains separate and is not claimed.
