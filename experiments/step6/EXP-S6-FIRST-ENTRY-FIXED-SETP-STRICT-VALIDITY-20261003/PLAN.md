# First-entry fixed WR setpoint, strict validity retained

Baseline: a1694e85; actual preceding RXTS images/source13d5c99b.
Previous control /2 acquisition, /12 tracking; no Ki/gain/threshold changes.
Previous short preflight reached <60ps but only2669ms qualified stability.
RX math was consistent; raw timestamp changes were observed while WR phase
setpoint was still actively corrected. That is not evidence isolating Ki.

## Single intervention

Current main-root firmware only. Boot-lifetime independent latch at the first
genuine WAIT(5)->TRACK(4), strict -60<CKO<60. Freeze existing setpoint (no manual
value), block all three WR phase writes and init modulo arithmetic. IPC cannot
undo this. Leave coarse time adjustment behavior unchanged; stop observation
on coarse/reinit/state exit. WRS shared ABI remains36. Master never latches.

Above +/-120ps, revoke Slave time output BEFORE hardware-busy return, even if
IPC tracking is disabled. Continue TRACK measurements at constant phase only
for diagnosis, with output invalid; NEVER automatically re-enable validity
after an excursion or a reset/init path within this boot. Frozen TRACK state
alone is therefore not PASS/validity evidence. No gain/calibration/RTL/SDC change.

Passive counters/query: pll fixed reports latch/entry UCNT/WR phase writes/WR
servo init count/frozen setpoint/revocation and actual SPLL init generation and
current/target phase shift. Existing coherent WDIAGS frame also reads SETP,
64-bit DMS and SPLL init count. No invented registers or bank switching.
Console query before/after capture only; acknowledge its scheduling impact.

## Tests and hardware sequence

1. Laptop actual Tcl/Python contracts; push before any Pain source build.
2. Pain ff pull, actual C baseline35cases plus intervention UBSan tests:
   one-shot entry,100 in-band updates,8 full64-bit/busy revocations, IPC toggles,
   all three writes/init modulo, loss/reset/coarse paths and Master unaffected.
3. Fresh role firmware, pin actual MIF hashes from Laptop/push, Pain pull,
   main scripts build_current -> compile_current -> program_current once.
4. Dashboard prerequisite check, bounded acquisition observation up to360s.
   Short capture/query until a genuine latch, never another candidate reprogram
   just because the observer missed the original entry. If no latch, record
   NO_ENTRY and stop. A capture may begin after the latch; report this clearly.
5. Read pll fixed before dwell; require enabled=1,latched=1, health intact.
   Same physical session, read-only strict frames with FIXED_MODE=1. First do
   a60s diagnostic. If still valid with constant SETP and fresh contiguous CKO,
   run330s strict capture in that SAME boot (no further console during capture).
   If revoked,60s is enough for diagnosis; do not label a330s-invalid run PASS.
6. Query pll fixed after capture. Require same entry,phase-write count,servo-
   init count,SPLL init,SETP and hardware target. Endpoint readbacks are not
   cycle-atomic proof. Raw packet history may be queried after dwell only.

Immediate capture stop: board reset/generation, sustained bad/stale data,
Master validity/link loss, Slave lock/link loss, SPLL init change, SETP change,
state not4 after latch. Fine >120 excursion invalidates output but is the
diagnostic result, not cause for extra gain tuning. Bound each command/query.

## Decision rules

Constant SETP + fresh CKO/DMS variation supports a remaining inner-loop or
timestamp/measurement/calibration effect; NOT proof of which one or of Ki.
If variation disappears, supports investigating outer WR controller response;
one run does not prove causality/reproducibility. Missing invariant/coherence
means INCONCLUSIVE. Strict goal only passes a fresh<60 entry and300s qualified
TIME_VALID/PPS and actual CKO<=120, not TRACK state or disabled feedback alone.

Laptop receives full raw/checksums and actual products, writes REPORT and
pushes, then Pain ff sync. Frozen milestones/protected archive untouched.
