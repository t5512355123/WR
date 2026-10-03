# Same-boot Master RX→Slave T4 continuity follow-up

Same actual1ab27d25 images, no compile input change, reprogram, reset,
calibration, parameter/threshold change or second reader. Laptop tested
existing paired11/details3/strict-reader1 cases and pushed plan3f80d656
before Pain ff pull and ONE capture. Previous goal turn was progress:
exact16 Main/timestamp joins exposed action-free8ns return ambiguity.

**PASS_PAIRED_RETURN_DATA_ONLY; strict300s NOT_ESTABLISHED.**
raw/observe/20261003T083252Z-paired-return.log completed267552ms, below
unchanged360s gate. Full32 Master RX/16 Slave TS4 immutable snapshots,
16 exact peer/port/domain/sequence/full64 pairs, UCNT1806..1821 and15
consecutive differences. No missing/fabricated pairs or failed guards.
Slave snapshot ID2 is a NEW snapshot, not the earlier Main-history capture;
do not join different windows by approximate host time.

Master T24P2389ps, raw phase2868..3864ps. All16 matched packets choose the
falling branch; ahead1 in11, ahead0 in5. Coarse return (raw Master rising
counter time−Slave T3) is exactly176000ps in ALL16 pairs. Fine correction
478.989..9474.991ps, CKO−1448.502..+3521.500ps. Full64 conversion uses
literal firmware truncation, no tolerance added to exact joins.

At1816→1817:

    raw phase:       2942 →3484ps (Δ542ps)
    ahead:           1 →0; falling selection remains1
    coarse return:   Δ0ps
    fine correction: Δ8541.992ps
    raw return:      Δ8541.992ps
    raw forward:    −772.995ps
    CKO:            +4656.998ps
    fixed deltas:    unchanged
    prior WR action: −697ps; current WR action0

This particular step FOLLOWS a real phase adjustment, so it is NOT action-free.
Earlier action-free Main/timestamp steps are separate records. Do not conflate
them. The matched packet proves this step's8ns component originates in the
recorded linearization correction, not a changed coarse return or DelayResp
serialization corruption. Arithmetic reproduces lib/net.c exactly. It does
not prove which physical counter was reliable or the correct calibration.

Source audit: both tops leave SPI and generic EEPROM GPIO outputs open;
no implemented path identified for carrying an acquired Master calibration
through reprogram. Master netif defaults2389ps and startup attempts storage
load; actual packet records confirm2389ps in this boot. Slave auto-calibrates
after lock; Master normally does not scan. This is a significant per-image/
boot calibration gap, not proof that Ki1 or a cable caused this failure.
Do not copy Slave calibration or fit a T24P value to suppress CKO.

One20s postflight raw/observe/20261003T083824Z-strict-offset-validity.log:
22 rows,11 rejected,0 strict60 entries,0ms qualified hold, trusted CKO
−2312..+2889ps, errors=[], no trusted valid-outside120. No300s extension.
Both original source/product checksums remain valid; no live JTAG owner
after completion. All failed/rejected raw records retained.

Next source-audited direction: a bounded, reversible temporary PTP-role
exchange using SAME per-board gateware, measuring original Master as Slave
with the built-in rising/falling calibrator, then restoring original roles
and checking the actual active T24P persists in RAM. Do not swap SOFs: their
timestamp-path placements differ. Do not call unbounded calibration force
or write an invented calibration parameter. A compact read-only calibration
status command can expose actual active value and scan provenance without
overflowing VUART. Normal Master Main PI is inactive; its inherited phase
Ki0 must NOT be assumed to lock when temporarily Slave. Gate calibration
on actual lock/scan success, with a fixed deadline and verified role restore;
if no measurement, report failure rather than use guessed data.

That next controller experiment is NOT executed by this follow-up. It must
follow Laptop edit/test/push →Pain pull/native/build/compile/program before
role changes. Strict60/120 and continuous300s remain required; physical
calibration success alone is not the goal.

12 follow-up products/raw/analysis SHA256 match on both hosts; original
95-file TRANSFER manifest is unchanged. FOLLOWUP_SHA256SUMS is separate.
Archive13 regular members:
/home/b10504072/wr-transfer-backups/exact-join-same-boot-return-20261003/products.tgz

    SHA256 593fdcd48125a4d70d8864537c524b07887a81650effe0d9d449e847cb92237d

Independent Laptop paired, decomposition and postflight JSON equal Pain
exactly. Four strict captures and the original Main pair are independently
revalidated by analyze_trial.py; no old capture removed or substituted.
Frozen milestones and protected Pain archive remain untouched.
