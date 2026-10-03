# Paired Master RX→Slave T4 — completed; strict300s NOT_ESTABLISHED

## Result and scope

**PASS_PAIRED_RETURN_DATA_ONLY; STRICT_OFFSET_TIME_VALID_300S=NOT_ESTABLISHED.**
Fresh exact Master→Slave time representation verified, not physical accuracy
or continuous stability. Previous~4ns jump not reproduced inside this snapshot:
NOT_EVALUATED, not FIXED. Smaller action-free~926ps CKO variation still prevents
a±120ps stable hold.

Main root only. Baseline3dd3604d; actual candidate/build source
**31bfaeb55f667719dbcc8690139f859598683ed4**. Only observer/analysis/tests and
metadata changed. Firmware, RTL/SDC/QSF/generated IP, PI/Ki/gain, calibration,
threshold, timeout, bootstrap, reset and port unchanged. Production diff against
baseline empty. Normal/2 acquisition,/12tracking and full64 strict<60ps entry/
>120ps Slave validity revocation remain in effect. Frozen milestones/protected
Pain archive not modified. No advisors, power-cycle, port switch or calibration.

## Tests, build and program

Laptop11paired/14TS4/10strict-reader-offset tests passed, including whole Tcl
observers. Native C on Pain: actual TS4 recorder, RXTS ring/linearizer,
35normal strict-servo cases and fixed diagnostic PASS under UBSan. Actual page
print tests reserve64bytes within1024-byte FIFO. Pain Python11paired/14TS4
tests passed with2/5Tcl tests skipped (no tkinter); they executed on Laptop,
not claimed executed on Pain.

Initial whole-observer fixture failed because Tcl converted mock suffix"01"
to"1". Only fixture formatting repaired, not a gate.8exact pairs accepted/
7rejected tested. Initial/final logs retained. Post-capture descriptive helper
adds no gate and passed3tests: decomposition, high TAI/partial overlap, refusal
of unvalidated data.

Fresh root firmware builds matched existing MIF pins:

    Master 4695471fd7f6c1ff1fd845574406741474a36deb59e6c8a748c416569561c1a6
    Slave  857037966187a1a551be92a67fa05b815e3e1ff096d863888897896dabc43d8d

Both full FPGA compiles succeeded, exported actual root output SOFs:

    Master 0cddc7a5ce4944776d9d4d58fb03732ee0e12a18059b7afac2a2d22e33550f22
    Slave  8226e5046ae62ac65e6d197aefcc27b872e65c595a381f4aa91e573edcf91f35

Compilation ended09:01:42 Master/09:13:29 Slave (+08,2026-10-03).
Timing NO, recorded but not experiment gate. Exactly one programming pair:
Slave09:14:30–09:14:49; Master09:14:49–09:15:08, both successful.
Authentication-input handling retry before programming caused no additional
FPGA operation. No credential recorded here. No reprogram/reset followed.

## Same-session startup and postflight

Initial saved dashboard: both links PASS, Master TIME_VALID1, Slave Main still
starting (frequency/phase/MainLock/PSTAT0), not new PHY failure. One reader at
a time for all observations, no bank race.

| Observation | Rows / accepted* | Fresh<60ps entries | Best qualified span | Trusted CKO ps |
|---|---:|---:|---:|---:|
|20s smoke|22/12|0|0ms|−618..+6989|
|ONE120s startup|132/71|9|1501ms|−485..+449|
|20s strict postflight|22/12|1|0ms|−221..+339|

*Includes freshness, coherent frame/update continuity and interleaved Master
health, not merely transport.10/61/10rejected rows preserved, not interpolated.
No reset/transport errors or trusted VALID-outside120 observations. This is
not cycle-by-cycle proof between reads. Postflight repeatedly exited, so
predefined extension gate failed: no300s run/PASS.

Final dashboard: both link gates PASS, five Slave locks1, Master TIME_VALID/
PPS_VALID1; Slave WAIT_OFFSET_STABLE, CKO+165ps, TIME_VALID/PPS_VALID0.
Pointwise lock is not offset-stability proof.

## Exact paired provenance

One capture20261003T012014Z-paired-return.log, actual285598ms (<360000).
Slave page0 request27394–27609ms; Master page0 request27736–27975ms. Both
requested before draining either, no repeated page0. Full32Master/16Slave
immutable histories read. Request timing is NOT cross-board atomicity.

Live MAC/clock IDs from raw mac get, both port1:

    Master 02:00:22:33:44:01 → 020022fffe334401
    Slave  02:00:22:33:44:02 → 020022fffe334402

These differ from previous boot's33:30 suffix. Current raw identity, not
fallback/historical assumption, selects peers. Reason not evaluated; do not
call it timestamp causality or rewrite EEPROM.

All page/serial/schema/source/port/domain/full-time/linearizer identities
validated.14accepted updatesUCNT266..279 match actual Master DelayReq RX to
Slave raw T4 EXACTLY, no tolerance;13consecutive UCNT+1 differences.2outside
overlap records stay unpaired. WR/SPLL generations/source constant; repeated
Master/Slave reset signatures={1 1 1 0 1}, link/PLL gates healthy. Master local
validity held; Slave invalidity allowed for diagnosis, not a data-only gate.
Physical RX accuracy, analogue skew and unexercised conditions remain unproven.

## Fine decomposition

analysis/laptop-paired-details.json saves14rows/13differences AFTER unchanged
primary gate. Full integer/Fraction identities precede descriptive float output.

| Quantity | Minimum ps | Maximum ps |
|---|---:|---:|
|CKO|−685.501|+240.494|
|raw forward|177102.997|178120.987|
|raw return|178348.999|179351.990|
|coarse return (Master coarse RX−Slave raw T3)|176000.000|176000.000|
|Master fine correction|2348.999|3351.990|
|Master raw phase|4738|5741|
|DMS|173996.490|174327.499|

Master T24P unchanged2389ps; all14pairs rising/ahead0. Previous falling/ahead
toggle case NOT exercised. No>=1000ps CKO transition here; prior~8ns/4ns
mechanism NOT_EVALUATED, not FIXED.

9differences have preceding/current WR phase actions zero. Useful steps (ps):

|UCNT|ΔCKO|Δforward|Δreturn|Δcoarse return|Δfine correction|ΔDMS|
|---|---:|---:|---:|---:|---:|---:|
|275→276|−925.995|+1017.990|−834.991|0|−834.991|+91.995|
|276→277|+593.002|−500.992|+684.998|0|+684.998|+92.010|

SETP before/after306ps in all three rows. Both legs moved opposite directions
while RTT/mean delay moved less. Investigate relative phase/fine estimation,
not solely return serialization or WR setpoint action. Main/Helper PLLs stayed
live: unchanged WR setpoint does NOT mean their PI/DAC outputs frozen. No proof
of physical jitter or Ki.

## Interpretation and next boundary

Historical300s TIME_VALID-only evidence did not enforce current60/120ps;
old bit-only PASS cannot establish current stability. Current boots differed
in phase selection/fine-phase context with identical control MIFs. Fresh
fitting/programming is not equivalent physical phase state or byte-identical
SOFs. Limitation, not proved cause.

Source: coarse RX timestamp queued with packet; lib/net.c calls
spll_read_ptracker(0,...,NULL) at dequeue. Return is ready; third argument
enabled, not ready. Receive code ignores return. Phase age/generation absent
from packet record. Candidate observability gap, NOT demonstrated cause.
No packet rejection/validity rule changed on this hypothesis.

Next unique direction: source audit/passive packet-aligned tracker ready,
enable/publication generation/age plus current Main phase error/update/output,
joined to accepted T1..T4. Prefer existing passive diagnostics; missing fields
would require a small versioned recorder extension/native tests, not ABI/RTL
or control changes. Follow Laptop→push→Pain pull/build/compile/program→raw→
Laptop report/push. Distinguish actual relative clock movement from estimator
age/error before changing WR Ki/Main PI/calibration or declaring300s hold.
No such next production modification made this round.

## Return and publication

90actual products/raw/analysis files passed SHA256 on both machines;
raw/TRANSFER_SHA256SUMS records them. Archive outside protected paths:
/home/b10504072/wr-transfer-backups/paired-return-20261003/products.tgz
SHA2568f8f34c948bde83cdf2ff5215bd63f39cf48ecbb6605ab25c80a8dd7aa2da239.

Independent Laptop reanalysis reproduced Pain JSON exactly. Extra Laptop
descriptive outputs/tests labelled separately, not part of original90files.
Root build/output contain actual products/identities; raw logs in this
experiment. Publication HEAD does not replace actual31bfaeb5compile identity.
Frozen milestones/protected archive unchanged.
