# Current status

**Current root: STRICT_OFFSET_TIME_VALID_300S = NOT_ESTABLISHED.**
Active experiment: EXP-S6-MASTER-RX-TO-SLAVE-T4-PAIRED-PROVENANCE-20261003.
Observer-only paired provenance round completed; production inputs unchanged.
Fresh native checks/full compile/one Slave→Master programming pair succeeded
from `31bfaeb55f667719dbcc8690139f859598683ed4`. Root output contains these
actual diagnostic products, NOT a strict PASS. Master32/Slave16 histories
validated;14exact full64 RX→T4 pairs,13consecutive differences. No>=1ns CKO
step in this overlap, but action-free275→276 moved−925.995ps, with constant
coarse return and fine correction changing−834.991ps. Both forward/return
terms varied; physical jitter versus phase estimation remains unproven.
The120s startup had9fresh<60ps entries, longest qualified hold1501ms. Postflight
had1entry, no positive qualified span, CKO−221..+339ps; no300s extension.
See the [paired report](experiments/step6/EXP-S6-MASTER-RX-TO-SLAVE-T4-PAIRED-PROVENANCE-20261003/REPORT.md).
Current root restores normal feedback and adds a passive coherent T1..T4/RTT
producer RAM history. Native tests, fresh full compile and one programming pair
completed from `4e0c2324095c8644dac7fb5426f69de0eadb392c`. These preceding
products are now superseded by the paired diagnostic. All16same-source records
passed full timestamp/RTT/CKO identities. With phase action absent, ~8.2ns return
jumps correspond to ~4.2ns CKO jumps; timestamp provenance is the next boundary.
The120s acquisition had13fresh<60ps entries, longest qualified hold2102ms.
Postflight retained both links/all Slave locks and Master validity, but Slave
CKO−2866..+2737ps, no qualified hold. Strict300s remains NOT_ESTABLISHED.
See the [completed TS4 report](experiments/step6/EXP-S6-COHERENT-FOUR-TIMESTAMP-RTT-DIAGNOSTIC-20261003/REPORT.md).
The preceding main-root intervention froze WR setpoint after first<60ps entry,
retaining strict >120ps invalidation, no automatic re-enable in that boot.
Native baseline/fixed C tests passed; both fresh compiles and one programming
pair completed from `fbd8febf3eab38e6d2734f859d911f1e6b10365f`.
Those previous fixed-setpoint products are now superseded. Late freeze
was confirmed; exact entry CKO was not sampled. The 60s capture had 38 fresh
matched updates, below preset40: diagnostic INCONCLUSIVE. CKO -375..+3731ps,
DMS176621..180942ps, SETP=-4719 and WR phase-write/init counts unchanged;
all observed Slave validity remained invalid. This suggests further coherent
four-timestamp/delay diagnosis, not proof of Ki or physical clock causality.
See the [completed report](experiments/step6/EXP-S6-FIRST-ENTRY-FIXED-SETP-STRICT-VALIDITY-20261003/REPORT.md).
Preceding passive RX timestamp recorder: fresh build/program succeeded from
`13d5c99b2b1898cf9cd9d9864288f7f9d5cccccf`, now superseded.
90s preflight reached <60ps but retained +/-120ps only2669ms; NOT300s PASS.
Two packet histories validated mathematically;64 rows,63 correct. Both used
falling selection; actual ahead/calibration accuracy remains unproven.
The new firmware revokes Slave validity outside +/-120 ps and reacquires only
inside strict +/-60 ps. Gains remain /2 acquisition, /12 tracking. Role-corrected
revision 2 passed 35 actual-C cases and fresh two-board compile/program from
`4ba9df5935fc0a6afae2c7bd29603f190936e627`. These preceding candidate images
have been superseded by RXTS, fixed-SETP, then normal-feedback TS4 products, NOT historical PASS images. Master validity is restored;
the completed 660 s capture had 1882 Slave rows (1849 trusted), CKO
-3158..+3839 ps, no <60 ps row, and zero qualified hold. All 496 sampled Master
health rows were valid; Slave TIME_VALID remained 0. No reset/transport errors.
Offset-bound 300 s qualification is NOT_ESTABLISHED. Frozen packages unchanged.

**Historical TIME_VALID-only Step6: PASS_TWO_INDEPENDENT_ROOT_CYCLES (2026-10-02).**
The frozen milestone additionally passed fresh standalone build/compile/program
at 20:03–20:34: 1192/1192 valid samples per board, Master/Slave spans
302952/302872 ms, no invalid rows or transport errors. See the
[standalone report](experiments/step6/EXP-S6-MILESTONE-STANDALONE-FRESH-REBUILD-TIME-VALID-300S-20261002/REPORT.md).
Experiment: EXP-S6-MASTER-HPLL-STEP64-REPEATABILITY-20261002.
Only Master HPLL physical-step accounting changed 34 → 64; Master bootstrap
2048 and Slave `/2 + /12` firmware stayed unchanged. Both root cycles completed
fresh firmware builds, full two-board FPGA compiles, Slave→Master programming
and >300-second sampled TIME_VALID windows on each board.

| Cycle | Master valid rows / span | Slave valid rows / span | Max gaps M/S |
|---|---|---|---|
| 1 | 1192/1192 / 302791 ms | 1192/1192 / 302901 ms | 257/257 ms |
| 2 | 1192/1192 / 302815 ms | 1192/1192 / 302885 ms | 258/256 ms |

No invalid rows or transport errors. All 3110 production inputs and both MIFs
match between cycles. Master Helper was locked and its phase tracker ready
after qualification. Frozen milestone images are the second-cycle images, compiled
from 7b6550123986a9d7cea5f4be0dbb8af1f5a019ab. The single Step6 package is
`artifacts/milestones/step6_global_time/source.tar.gz`, prepared as `source/`.
This supports two-run reproduction of the user's sampled TIME_VALID-only gate,
not universal startup reliability, fine timestamp accuracy or physical SMA skew.

- Branch: feat/file_cleanup.
- Latest session: both boards passed in two complete cycles; see the [current report](experiments/step6/EXP-S6-MASTER-HPLL-STEP64-REPEATABILITY-20261002/REPORT.md). The earlier bootstrap2048 single-session PASS subsequently failed after reprogramming with identical SOFs. That failure remains recorded; copying equality alone was not startup validation.
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

Historical Step6 records retain their original scopes. The Master-step64 repair
now has two independent root reproduction successes; the earlier single-session
package is superseded, not a second active Step6 milestone. Physical SMA/output
edge-skew measurement remains separate and is not claimed.
