# Main command-to-DCO account correlation

2026-10-03, Asia/Taipei. Completed on the operational root, no advisors.

## Verdict

```text
NATIVE_CONTROL_EQUIVALENCE           = PASS (tested trace, not formal proof)
FRESH_TWO_BOARD_COMPILE_PROGRAM      = PASS
COHERENT_DCO_ACCOUNT_DIAGNOSTIC      = PASS_DCO_ACCOUNT_DATA_ONLY
SUSTAINED_MAIN_SERVICE_BLOCKAGE      = NOT_SUPPORTED_IN_THIS_WINDOW
STRICT_OFFSET_TIME_VALID_300S        = NOT_ESTABLISHED
360S_EXTENSION                      = NOT_RUN (postflight <10s gate)
MILESTONE_OR_MERGE                   = NO
```

The completed capture has60 coherent private snapshots, normal transaction
progress in59/59 intervals and no observed L2 failure. This proves useful
diagnostic data, not physical SI5340 readback or Step6 PASS. WR CKO still
leaves inclusive+/-120ps. No60/120ps, freshness, completeness or deadline
condition was relaxed. Rejected/failed records are preserved.

## Exact workflow and source

Baseline: `eb12a587415fb0c55f620360ddb66c1066a0676b`, the Kp600 report.
Laptop source/testing push08b404f9, native-test compatibility pushf0f0f7ef;
Pain exact pull, native RTL/pin/C tests and both role firmware builds.
Both full Quartus compiles and the one programmed pair use:
`f0f0f7ef14b4e1a139f80e1ce131ecaa042575f1`.

Only hardware addition: private same50MHz-edge Main account capture, Slave
probes72/73/74. Master input tied0/outputs open. Marked blocks are removed in
source-equivalence tests, leaving baseline controller/top-level functional
source equal. Both actual firmware MIFs are byte-identical to the baseline.
Kp600/Ki1, boost20, frequency threshold20, preload1, /2 acquisition,/12 tracking,
strict validity, physical Main step16, Helper64, arbiter/bootstrap/timeout,
PHY/reset, firmware, SDB, QSF and SDC remain unchanged. Passive instrumentation
can change placement; cycle tests do not prove analogue hardware identity.

| Product | SHA256 |
| --- | --- |
| Master MIF | 8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5 |
| Slave MIF | 006d798a02699167337c6a417f14fd898b0ffad872e35a2c2e9250fbededd4e5 |
| Master SOF | db3ac3d150c9320a61d58621f0543856807ceebe6e424486e273742f8c9ba9e4 |
| Slave SOF | c75108d53b7e35559ee10b392e6e17f1837299d1b6c096a517e42a6cdf9bf276 |

Full compilation successful: Master14:09:41, Slave14:14:00. Reported setup/hold
Master+0.192/+0.040ns, Slave+0.256/+0.036ns. Full timing remains NO, not a gate.
One programming pair: Slave14:14:55-14:15:10, Master14:15:14-14:15:29.
No subsequent programming, powercycle, port switch, control injection or
second simultaneous JTAG reader. Root output retains these actual candidates.

## Native tests and observer corrections

Actual baseline/candidate controllers AND actual I2C engines were compared:
60,605cycles,33 captures,4 Main completions; immutable capture and tested
functional outputs matched. Pin-level liveness testL1 passed. Actual C history,
ptracker512-average, TS4, WR-servo35cases and fixed-SETP tests passed. Preserve
the known pin-test NACK/completion caveat: virtual completion is not sufficient
evidence of successful physical application. This observer stops on ACK,
timeout or L2 failure; no production ACK behavior was changed.

Final Laptop Python11/11 passed. Pain Python9 passed/2 tkinter tests skipped;
the missing toolkit was not installed. Both skipped paths were replaced by
successful actual Quartus Tcl offline tests, with hardware_session=0. Initial
Python tkinter-import failure is preserved separately from the successful retry.

Three pre-sample reader failures are retained, not called hardware failure:

| UTC start | Obtained samples | Stop and verified correction |
| --- | --- | --- |
| 06:20:49 | 0 | Health left a session active before instance discovery. Laptop5a77ee8d closes it; native lifecycle test added. |
| 06:24:18 | 0 | Full HDL IDs were not returned. Existing read_probe actual inventory shows four-character suffixes. Laptop968e5eb5 checks exact unique tuples72/73/74, widths1/64 and IDsA_V1/N_V1/S_V1; wrong-image tests added. |
| 06:28:02 | 0 | A private capture passed, but the combined10-read WR/lock publication frame could not become coherent within600ms. Its payload was not yet logged by that observer version, so it cannot be reconstructed or used as data. |

Laptop70193e25 splits WR(UCNT/CKO/SSTAT) and lock(H/M/P) into independently
guarded seven-read groups. It preserves600ms/group,120s overall and all
coherence checks, logs each group's start/end, and emits private full64 raw
before later reads so a later failure cannot erase it. Torn-group/lock-loss
tests passed on Laptop and native Quartus. Each correction was pushed BEFORE
Pain pull/testing/retry. These were observer-only corrections on the same
exact programmed pair; firmware/HDL hashes were rechecked and unchanged.
Log schema2 is distinct from hardware snapshot schema1.

## Completed diagnostic

Capture `raw/observe/20261003T063323Z-main-dco.log`, actual63,936ms,60/60 rows
and60/60 full64 raw snapshots. First3 smoke passed, then the same reader continued.
All independent group/sequence/schema/CTRL/publication/time bounds passed.
Both boards had8 health brackets each, stable reset signatures`{1 1 1 0 1}`;
Master local validity and all sampled Slave lock fields remained1. No failed
transaction, NACK, DCO error, timeout, first-loss or reset was observed.

| Metric | Actual result |
| --- | --- |
| Main successful account count | 19293 ->19934, delta641 |
| Main progress intervals | 59/59 |
| Target minus virtual applied | -17..+13 code |
| Abs residual <16 | 59/60; these rows -12..+13 |
| Abs residual >=8 | 16/60, descriptive only |
| Main / Helper maximum logical transaction latency | 1.22882 /1.22882ms |
| WR UCNT | 1022..1081 |
| CKO | -201..+227ps |
| Strict<60 / inclusive120 rows | 21/60 /43/60 |
| State4 TRACK /state5 WAIT | 33/27 |

The sole>=16 residual is final row59: target11119, virtual applied11136,
residual-17, starts19935/success19934, Main transaction active, pending1,
state2. It is one in-flight snapshot, not sustained starvation.

Applied is a VIRTUAL completion accumulator starting32768 and moving16 after
four-write completion, not chip register readback. Counter progress and latency
do not guarantee analogue phase, nor rule out every unsampled stall. WR,
lock and L2 groups are not atomic with the frozen account edge. Pending-based
maximum wait can omit/pre-date admission and includes old history; do not use
it to claim current starvation or convert suspicious wrapped values into a
credible wait measurement. No correlation here is causal proof.

## Strict preflight and postflight

| UTC start | Window | Rows/rejected | Fresh<60ps entries | Longest qualified span | Trusted CKO |
| --- | --- | --- | --- | --- | --- |
| 06:16:09 | 20s startup | 21/17 | 0 | 0ms | -1975495060..+2111534573ps, coarse startup low32 diagnostic, not fine phase |
| 06:17:57 | 120s acquisition | 127/69 | 9 | 604ms | -395..+354ps |
| 06:35:19 | 20s postflight | 23/11 | 1 | 0ms | -244..+160ps |

All analysis errors=[], trusted valid-outside-retention=0. Rejected rows cannot
extend dwell; some gaps/freshness rejections limit the demonstrated span. The
diagnostic CKO excursions independently show that this is not just a missing
300s timer. Startup low32 CKO is not full64 coarse-time evidence; actual
firmware60/120 validity uses full signed64. Postflight failed the predefined
fresh-entry+>=10s extension gate, so no360s/300s attempt was launched.

Final one-shot dashboard: Master/Slave TIME_VALID/PPS_VALID1, all five Slave
lock fields1, TRACK, CKO-55ps. Pointwise only. TAI1307/1311 are sequential
JTAG PPS snapshots, not simultaneous global-time alignment proof. No continuous
dashboard/JTAG owner left.

## Return and publication

Pain archive112 entries =111 manifest-covered products plus manifest; SHA256:
`4902e39116f6743c9526646a4d6ef6271a300113274ca835a1228fdd79b00550`.
Laptop validated every path/type before extraction, all111 hashes match.
Independent Laptop reanalysis of all3 strict and all4 DCO attempts exactly
matches Pain JSON values. Added Laptop JSONs/report are outside that original
transfer manifest. Actual build/output/source/publication manifests retained.
All frozen milestones and the protected Pain archive remain untouched.

## Next controlled boundary, not a concluded cause

Within this sampled window, sustained Main delivery blockage is unsupported;
most targets differ from the account by less than the current16-code admission
band while completed steps remain16. This supports testing ONE nearest-step
admission candidate, not changing Ki/gain, timing constraints or physical step.
The full-step rule is hysteretic: the same target can retain different applied
grid points depending on prior direction. Nearest rounding needs a consistent
tie rule at exactly8; symmetric>=8 would ping-pong between two16-code positions.
Before implementation, source-audit every admission path, preserve Master,
Helper, bootstrap and service/ACK behavior, and use actual-controller/pin
tests for ties, changing targets, boundaries, completion and fairness. Then
Laptoppush ->Painpull/full compile/program ->same strict verification. This
is a causal candidate, not an established fix. If delivery is normal yet WR
excursions persist, return to coherent phase/timestamp provenance. Historical
TIME_VALID-only300s and Step5 four-lock300s do not prove this stricter gate.
