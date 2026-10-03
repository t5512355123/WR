# Current-baseline Slave Main Kp600, strict offset hold

Goal unchanged: actual strict abs(full64 CKO)<60ps entry, then300s contiguous
qualified TIME_VALID with inclusive±120ps; >120ps must revoke Slave validity,
Master local validity preserved. No timing-closure gate or threshold relaxation.

Baseline8983d6e4ac042c719d9216e67f87b2aeafff1bea; actual prior full compile
25603ae2f2ff41f0f43ae93a4f9ef2829294a299. Both linked control inputs are equal.
Prior32-row window:31/31 Main/tracker progress, Main phase error−411..+502ps
and25/32 beyond±120ps, despite every phase-lock detector flag1. Tracker age
1–126ms; actual512-average publication cadence normal. CKO−307..+242ps.
Strict postflight best605ms, NOT300s. Those post-WR groups were independent,
not packet-time atomic; data do not prove Kp or WR Ki caused the failure.

## Historical audit before implementation

Source34013477fc225a8074840e2ba7e0dfb44e69873d and retained F4K B manifest/report
and full ABA comparison were inspected, not inferred from a consultant summary.
Old B=600 had64unique samples over119264ms, no phase/PSTAT lock, phase detector
in-band ratio0.136511,42F→P and42P→F handoffs, frequency error+17..+74.
Full ABA classification ARM_DATA_INVALID because A1 ended40907ms; valid B/A2
did not support adopting600. This is not previous successful600 evidence.

Old source Main frequency threshold50 and no bumpless-preload treatment.
Current source threshold20, bumpless preload1, phase Ki1 and stable Main phase/
PSTAT lock already established; new goal concerns actual remaining phase jitter,
not just reaching broad lock flags. Thus this is a different current-baseline
test, NOT repetition of an identical failed setup.600 is an existing permitted
F4K value; current default300, not a claimed upstream600 default.

## Exactly one functional change

firmware/configs/de5a_slave_identity.h:
DE5A_MAIN_PI_KP_OVERRIDE300 ->600. This shared Main PI Kp affects both frequency
and phase branches, NOT phase-only gain. Master identity unchanged.

Freeze: Main Ki1, boost20, threshold20, detector/count/floor/anti-windup,
bumpless preload1, WR acquisition/2 and tracking/12, strict60/120 validity,
Helper PI, DCO/arbiter/bootstrap/service/timeout, topology/PHY/reset, RTL/SDC/QSF,
phase averaging512, and all passive history/observer schemas/reader freshness.
Never consult advisors or alter frozen milestones/protected Pain archive.

Offline source contract must prove normalized Slave identity equals baseline
with only600->300 substitution, Master/full Main/wrh/control source byte-equal.
Existing strict/history tests and actual native regressions before build.
Save prior Slave binary before role builds; compare actual old/new bytes and
retain actual mpll_init disassembly. Master MIF MUST remain8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5.
Return actual Slave MIF hash to Laptop/pin/push/Pain exact pull before compile.

## Workflow and stops

Laptop edit/test/push -> Pain pull/native/role builds -> Laptop hash pin/push ->
Pain exact pull/root full compile/ONE Slave→Master programming pair ->20s strict
smoke and ONE bounded120s acquisition window. No repeated reboot, warm restart,
port switch, calibration or reprogram. Stop on wrong image/source, bank conflict,
transport failure, reset/generation or upstream link/Helper/Master-health loss.

If five Slave locks and Master validity good, ONE passive immutable32-row history
capture (page0 smoke then same snapshot, actual max240s), followed by strict20s
postflight. If fresh entry and≥10s continuously qualified evidence established
without errors, extend with one360s strict capture to attempt the true300s gate.
Otherwise report failure/limited evidence, not a pretend300s test.

Assess actual completed Main phase error, frame/lock/frequency handoffs and CKO,
not just detector flags. Compare with prior accepted32-row baseline cautiously:
different boots and independently copied groups do not establish causality.
No improvement/worse means NO_DIRECTION_SUPPORT, not permission for automatic
Ki change/gain sweep; keep failure evidence. Only a verified actual strict300s
gate may establish success, then repeat reproducibility before milestone.

Return actual products/raw/checksums to Laptop experiments, independent analysis,
REPORT and push, ff synchronize Pain, then start the next workflow cycle.
