# Slower WR CKO correction: acquire/24 + track/24, 15-minute settling

User explicitly requested slower correction and a 15-minute wait after
programming, plus an editable main-root one-command workflow without SHA gates.
No consultant, power cycle or canonical milestone promotion in this round.

Baseline controls: committed 8cda467d/c60f75e9 main-root inputs, Master
bootstrap2048/account64/reverse1, Slave MainKp300/Ki1/physicalstep16,
historical WR acquisition/2 and tracking/12. Change only the two WR division
constants to24. Preserve 60/120ps thresholds, wait retries, calibration,
SoftPLL/DAC/RTL/SDC/PHY/reset behaviour and validity semantics.

Unbuilt passive RXTS work is saved separately in a scoped Laptop Git stash,
not included in this candidate. The interrupted preceding milestone round
completed both compiles but stopped BEFORE programming due to JTAG ownership;
it is not a300s PASS. Preserve its candidate outside the canonical milestone
and restore the previously qualified archive's extracted source.

## Workflow

1. Laptop edit/test/push. Pain exact pull, native actual-C servo tests.
2. From `/home/b10504072/04_WR`, use the existing build_current,
   compile_current, program_current and dashboard scripts, through new
   `POST_PROGRAM_WAIT_S=900 ONCE=1 CLEAR_SCREEN=0 bash scripts/run_current.sh`.
3. One Slave→Master programming pair. Wait900s from successful programming
   completion, without JTAG observer or control writes during settling.
4. One dashboard after15minutes, then bounded15s phase-context smoke. If
   reader guards are valid, extend to a300s phase-context observation in the
   SAME boot. Do not count untrusted rows or repeated UCNT as fresh servo data.
5. Assess CKO range, strict<60 and<=120 counts, unique-update slope and state
   occupancy, all locks, link/reset identities, SETP/DMS and TIME_VALID. A
   single late dashboard value is not stability or causality proof.
6. If both boards are valid, run unchanged303s-per-board TIME_VALID verifier.
   If invalid after settling/trace, retain failure and stop; no auto retry,
   wider thresholds or another divisor in the same round.
7. Raw/products/checksums back to Laptop, independently recompute and write
   REPORT, push, Pain sync. Candidate is not a milestone unless qualified.

SHA files may still be GENERATED for research provenance, but editable root
build/export/program do not VERIFY them or require pre-pinned firmware hashes.
Compile/program success, non-empty expected SOFs and exclusive JTAG remain
necessary. Frozen milestones retain their original pinned workflow.

Integer division truncates towards0; |offset|<24ps produces zero correction.
Slower correction may reduce actuation changes but does not necessarily fix
timestamp jumps/noise or create an in-band state. Report hardware evidence.

## Same-boot observer amendment

After exactly900s settling, dashboard at15:07:28 showed Slave TIME_VALID0,
five locks1, WAIT/CKO-1423ps. The mode1 smoke then crossed a publication boundary
in all5 rows (epoch N→N+1); it is preserved as INCONCLUSIVE, not valid CKO data.
Host-only amendment: try existing mode2, separate individually guarded frames
joined by equal UCNT, on the SAME programmed boot. No epoch/validity guard is
weakened and no production rebuild/reprogram is needed for this host-only change.
