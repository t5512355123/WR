# Coherent four-timestamp RTT diagnosis

Baseline committed4687d6b6: fixed-SETP round formally INCONCLUSIVE (38<40),
strict goal NOT_ESTABLISHED. Its partial fresh data shows ~4ns CKO/DMS jumps
with unchanged WR setpoint/write/init counters. Source CKO=T1-T2+DMS; the
calibrated forward difference moved only1.06ns. This motivates measuring the
return leg and corrections, not another blind Ki/divisor change.

## Main-root candidate only

Restore WRH_FIXED_SETP_DIAGNOSTIC default0, i.e. normal /2 acquisition and /12
tracking with live full64 strict<60ps entry and >120ps revocation unchanged.
Add only a passive16-entry RAM recorder in the existing WR E2E wrapper. After
an actual accepted calculation/control update it captures raw-before-WR-delta
T1..T4, calibrated T1..T4, all four fixed deltas, raw/corrected RTT, DMS,
meanDelay, CKO, asymmetry, UCNT, pre/post state/SETP, independent Sync and
DelayResp sequence IDs, remote source identity, WR/SPLL init and phase-write
counts. Full signed64 seconds and scaled-ns are preserved; never turn absolute
TAI into signed64 picoseconds. Before/after SETP marks that stamps/CKO precede
that update's phase action; they are not post-action physical measurements.

Ring is not a control input. Same main-loop producer/shell consumer; page0
copies history before any console output. Later pages use the immutable copy.
No shared ABI, RTL, SDB, mailbox, detector, PI/Ki, gain, thresholds, timeout,
bootstrap, arbitration, PHY or calibration changes. Master T24P remains
unmeasured: no manual calibration, no copying Slave value. Master local
TIME_VALID must remain enabled. Frozen milestones and protected Pain archive
remain untouched. No advisor communication.

## Predefined workflow and bounded observation

Laptop actual-source contracts/decoder/Tcl tests -> commit/push -> Pain exact
ff pull -> native actual baseline/fixed C + actual recorder tests with UBSan
-> fresh role firmware -> measured MIF pins sent back to Laptop -> pin/push
-> Pain pull/build_current/compile_current/program_current, one pair.
No Pain code patch or alternate source/worktree. Use root scripts throughout.

After one program pair: dashboard and20s strict health smoke. Allow a single
bounded acquisition observation up to120s if startup locks are still settling;
do not start packet dump until both links, Master local validity and all five
Slave lock gates are established. Stop on transport/reset/image/bank conflict
or persistent invalid data. One reader/programmer at a time.

One single-session read-only TS4 snapshot: first two pages are transport/math
smoke; if sound continue the SAME frozen16-record snapshot. Total maximum360s
actual wall time,30s per command. Live two-board health and stable generation
checks before/after; preserve full raw reply hex and each page query timing.
Failure stops immediately with incomplete evidence retained. Do not restart
merely because observation expires. No need for Slave time to be valid to
diagnose acquisition; validity remains an honest live gate.

Data completeness requires all16 fresh unique accepted updates, correct
source/domain/sequence provenance, one stable init generation, and all
calibration/RTT/CKO identities reproducing with full fixed-point precision.
Adjacent-delta analysis uses UCNT+1 only; gaps never called cycle-causal. Raw
means before WR fixed-delta correction, not raw hardware descriptor. This
snapshot alone cannot establish physical clock accuracy or Step6 PASS.

Check whether large CKO/DMS jumps coincide with ~8ns return-leg/raw RTT jumps
while forward leg and fixed deltas are relatively stable, versus calibration
or both-leg changes. These identify candidate boundaries, not automatic
causal proof. Lack of complete/fresh identities = INCONCLUSIVE.

After packet capture one20s strict postflight; only if true fresh<60 entry and
no >120ps retention violation is observed extend normal strict capture to
the actual300s goal. Never use a snapshot-only data PASS as Step6 PASS.
Return raw/products/checksums to Laptop, analyze/report and push, Pain ff sync.
No automatic tuning. Next change follows the new actual evidence.
