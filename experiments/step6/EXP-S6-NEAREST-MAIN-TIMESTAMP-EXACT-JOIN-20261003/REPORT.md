# Exact Main/timestamp join — completed; strict300s NOT_ESTABLISHED

## Outcome

**PASS_EXACT_UPDATE_JOIN_DATA_ONLY. STRICT_OFFSET_TIME_VALID_300S=NOT_ESTABLISHED.**
The two independent immutable histories agree exactly for16 accepted WR
updates. Main and tracker advance in all15 intervals. Four action-free CKO
steps near4ns correspond principally to return-leg changes near8ns, while
post-accept Main error is much smaller. This narrows the next investigation
to return timestamp coarse/fine continuity and calibration provenance; it
does NOT prove physical jitter, a calibration bug, or a Ki cause.

Root only; frozen milestones/protected Pain archive untouched. No advisor,
port change, reset, power-cycle, calibration or parameter change. Baseline
c8460b08a3d94d0285ee4bbcf21637ad5d57f691. Firmware/RTL/QSF/SDC/generated IP
unchanged. Keep nearest Main admission8/9, completed step16, Kp600/Ki1,
Helper64, /2 acquisition+/12 tracking and full64 strict<60 entry/>120
invalidation. Only observer/analyzer/tests and experiment metadata changed.

## Implementation, verification and actual images

New observer freezes TS4 first, drains page0, then freezes the longer PHIST
ring. Skew<=20 actual accepted updates guarantees>=12 common records. No
second page0, command retry or simultaneous reader. Both page replies together
would exceed1024-byte FIFO, hence sequential draining. Same-update full64
CKO/DMS, state, pre/post SETP, phase-write and SPLL-generation words must match
exactly. Main/tracker copies are independently coherent, post-accept, NOT
packet-time atomic. Existing payload validators and old single-reader
deadlines remain unchanged. Combined capture ceiling480s is not a relaxed
old deadline or a300s validity qualification.

Laptop tests:10 paired observer/analyzer cases and strict-reader Tcl passed;
earlier PHIST9, TS414 and strict9 passed. Large signed timestamps, counter
wrap, skew20/21, torn/mismatched/missing data, health loss, counter regression,
stall reporting and actual complete Tcl command ordering/fail-closed stops
covered. Native Pain precheck: paired7/2 skips before argument repair,7/3
skips after; no tkinter there. Native Quartus whole-observer fixtures for
good/schema failure/skew failure PASS, hardware_session=0. Do not claim all
legacy Python Tcl skips reran individually on Pain. Actual C history,
ptracker512, TS4,35 strict-servo and fixed-SETP tests passed. Both firmware
rebuilds were byte-identical to pinned MIFs.

An offline nested-library argument bug was fixed in8b7e211b before the one
live paired capture. Native fixtures reran, compile-input diff remained empty;
no extra compile/program required by that observer-only correction. All
original precheck/repair logs remain under raw/tests. A Laptop post-return
comparison initially confused integer state-map keys with JSON string keys;
canonical JSON comparison fixed only the audit, not raw data or formal gates.

Actual native/firmware/full compile and program source:
**1ab27d25c6935ed5e6ddb5af129982f66a2265ac**.

|Role|Compile finished (+08,2026-10-03)|Setup / hold ns|
|---|---|---|
|Master|15:50:44|+0.192 / +0.040|
|Slave|15:58:10|−0.122 / +0.037|

Both successful. Full timing closure remains NO; not this experiment gate.
One Slave→Master programming pair succeeded: Slave16:00:47–16:01:02,
Master16:01:06–16:01:20. No reprogram followed.

Actual root output SOFs (NOT a strict PASS milestone):

    Master de6d0db8a0149acb1fbf718d3cd67ffe5e876cd2d396d6c9d0095c99b9befec2
    Slave  e52d24f8deab2f5bba142598743b9511e6a9f796fe4db6a328a18ae135059454

Unchanged role MIFs:

    Master 8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5
    Slave  006d798a02699167337c6a417f14fd898b0ffad872e35a2c2e9250fbededd4e5

Whole SOF hashes differ from previous compile; programmer payload checksums
match that pair. Neither fact proves identical physical boot phase/state.

## Same-session strict observation

|Window|Rows / rejected|Fresh<60 entries|Best qualified span|Trusted CKO ps|
|---|---:|---:|---:|---:|
|20s smoke|21 /11|0|0ms|−2826..+2628|
|120s acquisition|134 /56|0|0ms|−2775..+3444|
|20s postflight|22 /8|0|0ms|−2297..+3632|

All three formal analyses have errors=[] and no trusted VALID-outside120
observation. Rejected rows are preserved, not interpolated. No strict entry
and no>=10s postflight qualification, so the preset extension gate failed:
no360s extension, no300s claim. Formal freshness/update/gap gates unchanged.

Final one-shot dashboard: both links intact; Slave Helper/Main frequency/
phase/MainLock/PSTAT all1; Master TIME_VALID/PPS_VALID1. Slave WAIT/CKO−1313ps,
TIME_VALID/PPS_VALID0, consistent with offset-bound invalidation. Lock bits
alone do not establish fine-offset validity. No JTAG reader left running.

## Exact update evidence

raw/observe/20261003T080841Z-main-timestamp-pair.log completed334914ms.
One TS4 snapshot16 rows, one PHIST snapshot32 rows; freeze totals397/408,
actual skew11 accepted updates.16 exact common UCNT382..397,15 consecutive
differences; producer completion-time span15435ms. All identity/math/source/
generation guards passed. Ten live health brackets per role preserve reset
signature{1 1 1 0 1}, link/clock/Helper, Slave lock and Master validity gates.
Preexisting console boot/Follow_Up error text is retained and drained before
commands; it is not a fresh accepted-update record or cause determination.

Main sample_n increases58876 total,15/15 intervals; tracker15/15 advances,
publication ages36..134ms. All16 Main copies phase branch, error−239.258..
+182.617ps, PI output11199..11304. CKO−2685.501..+2747.498ps;0/16 strict60
and0/16 inclusive120. Main flag1 does not mean±120 WR accuracy.

|UCNT pair|ΔCKO ps|Δreturn ps|Δforward ps|Prior WR action ps|Δpost-accept Main error ps|ΔSlave tracker circular phase ps|
|---|---:|---:|---:|---:|---:|---:|
|388→389|+4060.989|+8007.004|−113.998|0|−147.461|−7|
|389→390|−4214.005|−8207.993|+220.001|0|+267.578|+222|
|393→394|+4098.007|+8154.007|−41.000|0|−364.258|−157|
|395→396|−3955.002|−7987.000|−76.996|0|+32.227|−11|

No current WR action in these pairs either; SETP remains−523ps. The fifth
>=1ns step386→387 follows actual−1281ps acquisition and is not action-free;
kept in full analysis. Use full64/Fraction timestamp identities before
descriptive floats. CKO=(return−forward)/2+asymmetry modulo production
sub-ps rounding; asymmetry/fixed deltas unchanged here.

This does not make Main post-accept samples simultaneous with RX, freeze
physical PLL/DAC outputs, or prove return serialization/coarse/fine cause.
But a raw Main error of a few hundred ps does not explain this record's
multi-ns CKO merely by a stale Main lock bit or absent Main updates.

## Why earlier boots looked better; next boundary

The preceding nearest pair reached CKO−254..+143ps and several brief<60
entries. This boot, with unchanged production inputs/MIFs, returns to
multi-ns excursions. Thus code/gain identity alone does not reproduce the
same timestamp/analogue boot state. The evidence does not assign blame to
Ki1 or the admission modification, nor establish either as a stable fix.

Source audit: netif_create_device() initializes Master T24P to2389ps.
calib_t24p_process() measures Slave; Master needs a calibration obtained
while operating as Slave and loaded from storage. Historical packet data
show Master2389ps but do not prove it was physically calibrated. A wrong
transition point could expose an ambiguous coarse-counter edge; that is a
hypothesis, not permission to fit a value to CKO or copy Slave calibration.
lib/net.c also uses tracker phase at dequeue and ignores ready return;
phase history here is post-accept, not Master packet-phase provenance.

Next unique boundary is a source-proven Master DelayReq RX coarse/ahead/
selected-edge/phase/calibration/freshness record matched exactly to the
Slave T4 that produced a jump. Reuse existing paired return reader/rings
where sufficient; add only missing passive freshness metadata if necessary.
Test known coarse/fine rollover model and preserve failed/unpaired rows.
Only then choose a calibrated continuity fix; do not suppress CKO jumps,
relax60/120, force TIME_VALID, or automatically sweep Ki/PI/thresholds.
Further reduction of sub-ns noise is separate from eliminating8ns ambiguity.

## Return/publication

95 actual products/raw/analysis files verified SHA256 on Pain and Laptop;
TRANSFER_SHA256SUMS records them. Returned archive has96 regular members
including manifest; allowed root/build/output/current raw/analysis only.
Archive outside protected paths:
/home/b10504072/wr-transfer-backups/main-timestamp-exact-join-20261003/products.tgz

    SHA256 946297cbb50a3e957eb7d4933dabd9bdbcbb5a487f6de1434bdb03bcf5450be5

Independent Laptop reanalysis reproduced all three strict JSON results and
the paired result exactly. Additional descriptive audit is separately
labelled analysis/laptop-independent-audit.json. Publication commit is not
the actual compile identity. All raw failures/rejections and preceding
experiments retained; no milestone promotion or main merge.
