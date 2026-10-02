# First-entry fixed setpoint — completed, strict goal NOT_ESTABLISHED

Baseline a1694e85, source1c54bb78. No gain/threshold/RTL/SDC change.
Laptop30 Python/Tcl tests passed,2 skipped (no native compiler).
After Laptop push and Pain exact ff pull:
- Actual baseline entire-servo C with UBSan:35cases PASS, Master preserved.
- Actual fixed diagnostic C with UBSan:100 in-band updates,8 full64/busy
  revocations, IPC/init/modulo/reset/coarse/loss guards PASS.
- Both fresh role firmware builds succeeded. Actual MIF pins:
  Master1777c0d61dc12a5c639e9e8502294b56d7c9bef905b860f0a84c6d90b85aa91d,
  Slave406a7cabddd30417aba1556eaf7bb5c2f7d741809eb30bc60daf1a147589b48a.

## Actual hardware sequence

Both full FPGA compiles succeeded from
`fbd8febf3eab38e6d2734f859d911f1e6b10365f`.
Slave compile/export completed2026-10-03T02:03:47+08:00.
Master/Slave MIF pins matched. Later observer/analysis/plan/test commits change
no firmware, HDL, QSF or SDC used by these builds; no further reprogram.

| Role | Actual root SOF SHA256 |
|---|---|
| Master |845d3c29e1de842cfa48c41105280d82c8c065a9cc830b4cc5cc94274d42b939e|
| Slave |e3428766e254c5fc0dffcfabaec5b264913802133926cba2c6912d24a5eca0b1|

Slave then Master programming succeeded once, ending02:05:05.
First dashboard02:05:52: both links up, Master local TIME/PPS valid; Slave
Helper locked but Main still acquiring. No power cycle. Timing remains open,
Master setup+0.192ns /Slave-0.659ns; no timing acceptance claim/change.

## Observer repairs, preserved evidence

Initial120s requested capture actually stopped after4313ms/5 rejected rows:
the extended all-fields frame crossed publication epochs. Correct classification
INCONCLUSIVE, NOT a120s hardware test. The first split-context20s smoke also
stopped after5 rejected rows. Splitting alone was insufficient: independent
short-context retries were needed. These failed raw logs/results are retained.

Laptop repair/tests/push -> Pain pull, no control or image change:
primary seven-read frame retained; separate guarded SETP and64-bit DMS frames
joined by actual UCNT. All three epochs and joined UCNTs retained. SPLL init
remains a separate passive guard; no cross-group cycle-atomic claim.

Final20s retry smoke:23rows,14 strict-trusted,CKO+3349..+3660ps,
state5:9 /state4:5, zero qualified hold, no transport/reset error.
Laptop expanded58tests passed,2skips (native compiler absent). Pain native
baseline/fixed C passed before builds; postrepair9offline tests also passed.

## Late entry and bounded fixed-phase salvage

Query near6min (02:11:20 completion) showed latched=0,writes=31,inits=2,
SPLL init=1. Therefore original bounded acquisition was not established.
Later smoke showed state4. A new query confirmed latch1,entry update600,
SETP/current/target=-4719ps,writes56,inits2,SPLL init1,revoked1.
This is a LATE_ENTRY_SALVAGE (PLAN amendment), not successful original entry
timing. The firmware's qualified-entry latch is source-proven; exact entry
CKO was not captured in observer raw, so do not claim an independently sampled
<60ps entry or a300s qualified interval from it.

One60s read-only fixed-mode capture, same physical boot:
`raw/observe/20261002T181842Z-strict-offset-validity.log`.
All63rows kept. Strict analyzer accepted23/rejected40 because contiguity,
read/freshness guards remain mandatory. All strict-trusted states4;
CKO-370..+3730ps, TIME_VALID invalid, qualified span0, no valid-outside120 row,
no transport/reset/invariant-stop error. No330s invalid dwell was run.

Diagnostic matched-context analyzer identified38unique fresh updates:

- CKO-375..+3731ps.
- DMS176621..180942ps.
- Adjacent OBSERVED CKO differences-3948..+4046ps (not necessarily consecutive
  producer updates; never label skipped intervals cycle-causal).
- SETP=-4719 throughout; before/after WR phase writes56,WR servo inits2,
  SPLL init1,current/target=-4719,entry600,revoked1 all unchanged.
- Diagnostic verdict INCONCLUSIVE:38 is below preset40 minimum. Do not lower
  the minimum after looking at the data. Strict goal NOT_ESTABLISHED.

Exploratory midrange grouping of these38 updates:lower13 rows mean
CKO-226.692ps /DMS176744.462ps;upper25 rows meanCKO3512ps /DMS180635.36ps.
Thus both CKO and DMS shift roughly4ns while WR setpoint is constant.
Source `proto-standard/servo.c` explicitly computes CKO=T1-T2+DMS, so
calibrated forward difference T2-T1=DMS-CKO=176622..177682ps (range1060ps).
This is not the uncalibrated wire/RX difference or an independent timestamp
measurement. Asymmetry/corrections are not separately captured here, so do
not declare an exact reverse-path8ns fault from this algebra alone.

## Interpretation and next direction

There is credible partial evidence of offset/delay jumps without further WR
phase writes, but the preset diagnostic completeness gate is NOT met.
This does not prove Ki, physical clock movement, ahead-bit error, calibration
error, or controller causality. It makes same-update four-timestamp/raw-vs-
calibrated delay diagnosis more useful than another blind Ki/divisor sweep.
Next source audit should capture raw/calibrated T1..T4 and RTT/asymmetry in
one producer RAM snapshot plus the corresponding endpoint timestamp evidence,
looking for coarse-period/half-period jumps, especially the return path.
Master T24P remains unmeasured; do not copy Slave calibration or force a
disruptive Master calibration just from this report.

This candidate deliberately freezes/revokes and cannot automatically acquire
validity again in the same boot after an excursion; it is diagnostic, NOT a
production PASS milestone. Restore normal feedback when preparing the next
controlled candidate. No advisor messages, no milestone/protected archive
changes. All products/raw returned to Laptop and checksum-verified before
report push; readers stopped. Strict300s goal remains active/unachieved.
