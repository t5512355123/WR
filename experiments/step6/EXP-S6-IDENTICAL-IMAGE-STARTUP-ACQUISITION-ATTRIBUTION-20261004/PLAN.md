# Identical-image startup/acquisition attribution

Objective: explain why the same main-root FPGA configuration can have
TIME_VALID300s success in one boot and fail acquisition in another. Do not
replace this with a new gain sweep or a relaxed/forced valid bit.

Authoritative baseline: main-root954b4d86; production manifest418bb254,
3117 inputs; MIF18a51d78/91c5d7f9; root SOF33e58bf4/fa5e4d2c; RBF payloads
8e5f1ab2/886650e7. Prior independent8e7d7963 images have different SOF
metadata but BYTE-IDENTICAL RBF configuration payloads and timed out in two
600s same-boot readiness attempts. Slave then had allfive locks1, servo5,
CKO-2353/-2460ps, TIME_VALID0. That failure remains preserved.

Current preflight2026-10-04T08:16:42: both TIME_VALID/PPS_VALID1, Slave
five locks1, servo4, CKO-104ps. New root programmer logs show Slave08:11:07
and Master08:11:26. This is NOT late recovery of the midnight failed boot.
Keep those logs and the preflight before another programming action.

First Laptop support-script/analyzer/test changes ->push ->Pain exactpull.
No production input changes. Preserve the current live, already-valid boot;
15s phase-context smoke (mode2, separate guarded frames joined by UCNT),
then unchanged303s-per-board TIME_VALID qualification. This initial read-only
baseline intentionally precedes programming so the successful state is not
destroyed. No separate reader may run simultaneously.

Next controlled replay must obey Laptop ->GitHub ->Pain build/compile ->
configuration comparison BEFORE programming ->Slave/Master program ->single
reader immediate phase/context startup trace. Fresh RBF payloads must match
both retained reference payloads, otherwise stop and do not call it the same
image. Capture CKO, UCNT, SSTAT, SETP and DMS with each group's epoch/valid/
inverse guard and a UCNT join; record health/reset signatures separately.
Do not claim atomic cross-group or per-clock causality. Native actual-C tests
validate the existing entry/latching policy without changing it.

Analysis separates initial acquisition, TIME_VALID retention, phase accuracy,
duplicate UCNT observations, adjacent update arithmetic and actuator response.
3=SYNC_PHASE,4=TRACK_PHASE,5=WAIT_OFFSET_STABLE. SYNC arithmetic/2 and TRACK/12
stay fixed. Test truncation towardzero for negative CKO; reject torn/context-
mismatched frames and same-UCNT conflicting payloads. Never infer action pairs
across skipped updates or rejected observations. A software arithmetic match
does not prove the physical actuator followed it. Low32 startup CKO is not
full64 coarse-time evidence.

No PI/gain/threshold/calibration/timeout/arbiter/bootstrap/PHY/reset/SDC/RTL/
SDB/production firmware changes; no advisor or powercycle. The protected archive
and frozen milestones remain untouched. Image mismatch, transport/generation/
reset change, competing owner, or persistently invalid phase context stops the
affected capture, preserves it and requires an evidence-backed observer repair.
Qualification remains every sampled STATUS_TIME_VALID1 for>=300s with complete
DONE/index/board/gap checks. A valid dashboard is not300s proof, and a successful
retention window is not proof of deterministic startup or precise phase.

Return/checksum raw records to Laptop, independently rerun analysis, write
REPORT.md and push before choosing the next controlled action. Keep the goal
active until the unexpected same-configuration behaviour is causally explained;
do not close it merely because another favourable boot happens to pass.

Controlled replay runner: scripts/experiments/replay_identical_image_acquisition.sh.
It requires the preserved current live qualification first, builds firmware and
both images through existing root scripts, checks all3117 input bytes and both
RBF payload hashes before programming. It captures the existing dedicated
acquisition reader (300s health arming ceiling,10s healthy streak,600s acquisition
ceiling; first TRACK is a stop). Unexpected observer stops are INCONCLUSIVE,
not failed firmware acquisition. No repeated programming to fish for a pass.
If initial time validity is observed, unchanged303s-per-board qualification
follows in that same boot. Freeze every functional input, include normal
termination/censoring and programming wall times, and report the outcome even
when it is unfavourable.
