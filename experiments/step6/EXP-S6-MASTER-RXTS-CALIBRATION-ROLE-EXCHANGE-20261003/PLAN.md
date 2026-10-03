# Master RXTS measured calibration on same gateware

Status: PREPARED; hardware NOT RUN. Goal remains strict300s, not a calibration-only PASS.

## Evidence and single intervention

Preceding source/report6b27b5e974f241c561d3610c23d3da0c854bd6a7:
16 exact Master RX→Slave T4 pairs; coarse return176000ps constant.
1816→1817: ahead1→0, falling1, raw phase+542ps, fine correction+8541.992ps,
CKO+4656.998ps, following an actual−697ps WR action. Earlier separately
frozen Main/TS4 history had four action-free~4ns CKO changes with~8ns return
changes. These captures are NOT a shared snapshot and are not merged by host time.
Master activeT24P2389ps is the startup default, not demonstrated as measured.
The built-in calibrator source explicitly requires Master to operate as Slave
once on its own gateware. No connected persistent calibration storage was
identified in the current tops. Priorboot/role state may therefore explain
reproducibility differences; this is a hypothesis, not proven Ki causality.

Add ONLY `calibration status`: invoke existing bounded passive status printing.
Leave all original calibration control branches intact. Add an explicit bounded
role-control operator, separate from read-only dashboard and normal programmer.
No default T24P override, guessed value, calibration force, PLL command, gain,
threshold, timeout, bootstrap, arbiter, mailbox, PHY, reset, RTL/QSF/SDC/SDB edits.
Slave Kp600/Ki1, /2 acquisition+/12 tracking, admission8/9 and physicalstep16 stay.
Original Master Kp300/Ki0 also stays: temporary Slave lock might fail. If it does,
record failure and restore; do NOT treat old lock bits or an unfinished scan as
calibration. Frozen milestones and the protected Pain archive stay untouched.

## Ordered workflow and bounds

1. Laptop actual-dispatch/source/Tcl offline tests; push prepared source.
2. Pain ff-only exact pull; native C and native Quartus offline Tcl fixtures.
   Build both actual firmware roles, return new MIF hashes, pin on Laptop/push.
   Pain exact pull, normal root firmware build/full compile; one normal
   Slave→Master FPGA programming pair. Do not swap SOFs for calibration:
   each board must measure on the gateware placement it will actually use.
3. Normal-role read-only startup/lock gate. Run explicit operator once, only
   after original roles/Helper/Slave five locks and fresh Master scan0 are proven.
4. Original Slave1-11.2 becomes Master FIRST; original Master1-11.1 becomes
   Slave SECOND. Fixed allowlist: `ptp master start`, `ptp slave start`, `ptp`,
   `calibration status`. Each control delivered once, no automatic retry.
5. Built-in scan allowed240s; total operator actual600s, last120s reserved
   for restoration. Source-matched completedR/F states2/count5/range9500,
   normalized0..7999 transitions, ptracker ready, all Main lock bits and
   PSTAT, fresh active midpoint, two unchanged status confirmations required.
   C truncation-toward-zero used for midpoint. No scan fallback accepted.
6. Restore original Master first, original Slave second; each independently
   attempted once with fresh trusted link/reset/transport precheck. Confirm
   runtime roles and retained measured Master activeT24P. Even calibration
   failure enters restoration; reset/link/transport loss forbids blind writes.
   Any failed restoration is UNKNOWN/FAIL, not a restored claim.
7. Same still-live normal session: strict20s smoke, at most120s acquisition,
   strict20s postflight. If actual strict gate holds≥10s, one bounded360s
   capture may attempt the real300s goal. Otherwise no long goal capture.
   The normal reader's freshness, rejection, completeness and deadlines stay.
   A successful scan alone is NOT TIME_VALID300s and NOT a milestone.
8. Return all products/raw/checksums to Laptop, independent analysis/report,
   publish and Pain ff sync. Preserve every bad row, timeout and old evidence.

## Stop and interpretation

Single-owner JTAG throughout. Image/source mismatch, pre-existing completed
Master scan, calfail, reset/generation change, link/clock loss, untrusted
transport, malformed/duplicate status, wrong PTP role, incomplete scan,
wrong active midpoint or deadline stops measurement. Restoration is attempted
only while trustworthy. No retries, guessed transitions or widened bands.

Actual goal: fresh strict abs(CKO)<60ps entry; then inclusive abs(CKO)≤120ps
and Slave TIME_VALID maintained for300s; violation withdraws validity. Timing
closure not a gate. Master/Slave validity and lock/source invariants still apply.
Only this full evidence can qualify the root or a milestone.

If measured calibration removes coarse/fine jumps and improves strict hold,
that supports this path; role exchange also reinitializes PLLs, so improvement
alone is not isolated causality. A fresh reprogram must subsequently reproduce
the final automated fix before declaring reproducible success. If temporary
Master image cannot lock as Slave, calibration remains NOT_MEASURED and the
limitation is recorded rather than filling in a number from another board.
