# Slave Main nearest-step admission trial

2026-10-03, Asia/Taipei. Operational root, no advisors or powercycle.

## Verdict

```text
SOURCE_INTEGER_NATIVE_PIN_C_TCL_TESTS = PASS (not formal/analogue proof)
FRESH_TWO_BOARD_COMPILE_PROGRAM      = PASS
COHERENT_DCO_ACCOUNT_DIAGNOSTIC      = PASS_DCO_ACCOUNT_DATA_ONLY
STRICT_OFFSET_TIME_VALID_300S        = NOT_ESTABLISHED
360S_EXTENSION                      = NOT_RUN (postflight <10s gate)
MILESTONE_OR_MERGE                   = NO
```

The candidate changes admission, not physical step. Delivery remains active
and its virtual residual is narrower, but WR CKO still leaves inclusive120ps.
No60/120ps, freshness, sample-gap, deadline or completeness requirement was
relaxed. More transactions are not evidence of more stable physical phase.

## Workflow and exact source

Baseline `bf0651769e9abe373d220d9444dc79ce91edc814`, the preceding passive DCO
report. Laptop implementation/tests/push: `ba3fa6857a5315c35d873d834660f023012263a5`.
Pain exact pull/native tests/firmware rebuilds; Laptop precheck push, Pain pull.
Both full Quartus compiles and the one programmed pair use
`a45da74188d9ae325ac1c176bde74920018c0be4`.

One production treatment: Slave Main both load-side and idle admission use
increment gap>=8, decrement gap>=9 instead of16. Exact midpoint consistently
selects the upper16-code grid point; symmetric>=8 would chatter. Completion
still adds/subtracts16 only after the complete I2C command. No target snap,
partial accounting or changed physical FINC/FDEC. Default0 preserves Master.
Helper64, arbitration, bootstrap, ACK/order, timeout/reset/PHY, all firmware,
Kp600/Ki1, /2 acquisition and /12 tracking, strict60-entry/120-retention, QSF,
SDC, SDB and observers unchanged. Hardware placement is not an analogue
identity guarantee. Reused observer control_changed=0 describes its actions,
NOT absence of this production admission intervention.

| Product | SHA256 |
| --- | --- |
| Master MIF | 8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5 |
| Slave MIF | 006d798a02699167337c6a417f14fd898b0ffad872e35a2c2e9250fbededd4e5 |
| Master SOF | 7746d086f9d3bf99d95c45d2ec4329413ef3a718d36786e18633de6ab3c48bbc |
| Slave SOF | 60b501411bc725ad4b1cf17db25d5f87d5b318291fa46032e598fd65ba84cdad |

Full compiles successful: Master15:04:23, Slave15:11:49. Setup/hold reported
Master+0.192/+0.040ns, Slave-0.122/+0.037ns; full timingNO, not a gate.
Programming once: Slave15:13:11-15:13:25, Master15:13:29-15:13:44.
No reprogram, reset command, powercycle, port switch, live calibration or
simultaneous second JTAG reader. Root output retains these actual products.

## Prechecks

Laptop/Pain source tests4 include all65536 targets over their nearby grid
points, both tie directions and unsigned bounds. Default-mode actual RTL/I2C
equivalence passed60605cycles/33captures/4completions. Actual enabled
controller/I2C pin model passed32 positive/negative residues, repeated-load
hold, target change in flight,0/65536 boundary fixtures, full16 completion and
Helper service under Main contention. Both pin liveness runs passed.
These are tested traces, not formal proof or physical chip readback.

Native actual C phase-history/ptracker512/TS4/strict35/fixed-SETP tests passed.
Both role MIFs byte-match preceding builds. Laptop observer11/strict9/reader
Tcl1 passed. Pain9/2tkinter-skips were covered by native Quartus offline Tcl
tests with hardware_session0. The known NACK/completion-account defect is
preserved, not declared safe; actual observation stops on NACK/error/timeout.

After return, Laptop4/11/9/1 tests passed again. An initial post-return command
used nonexistent test_step6_strict_reader.py; no test ran under that name.
Correct test_step6_strict_reader_tcl.py then passed. No hardware/source repair
or discarded data resulted from this invocation error.

## Actual diagnostic

`raw/observe/20261003T071703Z-main-dco.log`:60/60 coherent full64 snapshots,
actual63522ms. First3 smoke passed and the same session continued. All
private schema/sequence/timing and separate WR/lock publication guards passed.
Both boards have8 health brackets, reset signature{1 1 1 0 1} stable, Master
validity1 and all sampled Slave lock fields1. No ACK/NACK, DCO timeout, failed
transaction, first-loss or reset observed. Slave time can become invalid as
required when offset leaves the band; this is not a diagnostic lock failure.

| Metric | Actual |
| --- | --- |
| Main completed virtual-account count | 29403->38929, delta9526 |
| Main progressing intervals | 59/59 |
| Target-minus-virtual-applied residual | -11..+11 code |
| Abs residual<=8 /abs residual<16 | 51/60 /60/60 |
| Main/Helper max logical transaction latency | 1.22882/1.22882ms |
| WR UCNT | 155..215 |
| CKO | -254..+143ps |
| Strict<60 /inclusive120 rows | 31/60 /47/60 |
| State3 SYNC /4 TRACK /5 WAIT | 2/37/21 |

All9 residuals outside8 occur with a transaction active;6 Main-owned and3
Helper-owned. Several pending bits are0 while the Main transaction is already
active; pending0 alone does not mean no service. No>=16 residual sampled.
Do not infer continuous admission or perfect analogue application from these
points. Applied is a virtual full-command accumulator, not SI5340 register
readback. Max latency includes prior history. Groups are not cycle-atomic.

The preceding window had641 completions over63936ms, residual-17..+13 and
CKO-201..+227; this window9526 over63522ms, residual-11..+11 andCKO-254..+143.
The intervention visibly changes activity; it does not establish sustained
stability. This is not randomized paired sampling, so percentages/ranges must
not be presented as statistically proved improvement or causal root isolation.
Stable fixed-target pin tests do not exclude extra actuation under noisy,
changing real PI targets.

## Strict verification

| UTC start | Window | Rows/rejected | Fresh<60 entries | Qualified span | Trusted CKO |
| --- | --- | --- | --- | --- | --- |
| 07:13:56 | 20s startup | 24/24 | 0 | 0ms | none (Slave lock gate0 throughout) |
| 07:14:40 | 120s acquisition | 132/67 | 15 | 3187ms | -1529..+1444906203ps |
| 07:19:07 | 20s postflight | 24/9 | 4 | 607ms | -212..+210ps |

All formal analysis errors=[], trusted valid-outside120=0. Acquisition has
coarse startup low32 CKO values, not fine full64 phase evidence. Supplemental
coherent TRACK/WAIT subset contains98rows/-1529..+5048ps, including50outside120;
postflight21rows/-212..+210ps includes13outside120. This subset is descriptive,
not substituted into the strict dwell calculation or used to erase rejects.

`analysis/trial-audit-laptop.json` records overlapping rejection reasons:
acquisition21 frame-invalid,29 Master-age>1500ms,33 gaps>1000ms,14 skipped
updates. Postflight3 frame-invalid,4 Master-age>1500ms,3 gaps>1000ms. Reader
scheduling limits observable dwell and warrants a bounded efficiency audit,
but real coherent excursions remain, so fixing the timer alone is insufficient.
Postflight failed fresh-entry+>=10s gate; no360s/300s attempt launched.

Final one-shot dashboard: Master time/PPS valid1; Slave all five locks1,
WAIT_OFFSET_STABLE, CKO104ps, time/PPS valid0. This is consistent with120ps
invalidation then waiting for a NEW strict<60ps entry. Being at104ps alone
does not satisfy reacquisition. No continuous dashboard left occupying JTAG.

## Return and next boundary

Pain return archive90entries=89 covered products plus manifest, SHA256
`ed86bca20f896b20f5a8efd01adc1ff805d500a705acbfaf1455a549d4ec582c`.
Laptop validated every path/type before extraction and89/89 product hashes.
Independent Laptop3strict/1DCO reanalyses match all Pain JSON values. New
Laptop analyses/report are outside the original transfer manifest. All raw
rejected samples retained. Frozen milestones and protected Pain archive
untouched; unrelated old logs/ignored work caches preserved.

Nearest admission is an unqualified candidate, not a Step6 milestone. Do not
blindly tighten admission further or blame/change Ki. Next isolate actual
Main phase-error/PI-target/tracker freshness against coherent WR timestamp
terms, retaining source-proven units and independent group timing; first
prefer existing passive producer history on the same verified image. If Main
phase really settles yet CKO jumps, return to forward/return timestamp/phase
provenance. If actuation increases while Main phase still oscillates, diagnose
the dynamic quantized loop with measured input/output before another single
control change. Separately audit JTAG scheduling without relaxing1000ms-gap,
1500ms-Master-health,2000ms-update-age or coherence requirements. Historical
TIME_VALID-only300s and Step5 four-lock300s do not prove this stricter goal.
