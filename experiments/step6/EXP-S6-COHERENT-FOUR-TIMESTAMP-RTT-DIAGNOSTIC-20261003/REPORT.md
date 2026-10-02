# Coherent T1..T4/RTT — completed; strict300s NOT_ESTABLISHED

Baseline4687d6b6. Normal /2 acquisition + /12 tracking restored by disabling
the opt-in fixed-SETP diagnostic. Strict full64 acquisition/revocation unchanged.
Only passive producer RAM/paging and a read-only observer added. No Ki/PI,
threshold, calibration, timeout, RTL, SDC or frozen-milestone change.

Laptop TS4 decoder/native-source contracts and actual Tcl observer tests:
14tests OK after repairs; strict observer/300s tests10OK; VUART tests25OK;
WR strict/fixed source tests6OK with1 native-compiler skip.
Initial failed fixtures are retained: a Main-lock fault was incorrectly applied
to Master rather than Slave; mock page array conflicted with observer scalar.
The whole-observer test also found a real Tcl64-bit STATUS output narrowing:
fixed by formatting both32-bit halves, not by removing the high-bit gate.
Actual full observer now verifies same-snapshot smoke/extension and immediately
stops on changed math or reset identity. Data-only PASS cannot become Step6 PASS.

After Laptop source push4bec6e32 and Pain exact pull, actual recorder C with
UBSan passed immutable-field packing, filtering, pre/post action boundary,
overwrite, frozen pages and full signed64 tests. Actual strict entire-servo C
passed35cases; fixed diagnostic regression passed100in-band updates and8full64
revocations. Pain TS4 Python14tests OK,5Tk skips (executed on Laptop).
Both fresh role firmware builds succeeded; actual text+data+bss159844/159804
bytes within196608-byte memory. Measured MIF SHA256:

- Master4695471fd7f6c1ff1fd845574406741474a36deb59e6c8a748c416569561c1a6
- Slave857037966187a1a551be92a67fa05b815e3e1ff096d863888897896dabc43d8d

Pins returned to Laptop and pushed before Pain build_current rerun. Both pins
matched again. The actual full two-board FPGA compile source is
`4e0c2324095c8644dac7fb5426f69de0eadb392c`; Master and Slave full compilation
and root output export succeeded. Retained root output now belongs to THIS
normal-feedback diagnostic, not the preceding fixed-SETP candidate.

## Hardware identity and workflow

Fresh compiled SOF SHA256:

- Master: ca0a75ee1572dde4d4e7692a924ef5c1773d7cdb9e09308f946cbb60bcc8825a
- Slave: 3b6334440410ac211ecaad3c27fe39fb13ac0de81c79555052a2aad7264e0d2c

One programming pair via root scripts: Slave successful2026-10-03
03:18:49–03:19:08+08:00; Master successful03:19:08–03:19:26. No reprogram,
reset, port change, shutdown or power-cycle followed. Timing remains NOT_CLOSED
and is documented, not an acceptance gate. No advisor communication.

Laptop edits/tests/push -> Pain exact ff pull/native tests/fresh role builds
-> actual pins returned to Laptop/push -> Pain ff pull/root build/compile/
program -> one reader at a time -> raw/products back to Laptop -> independent
analysis/report/push. `raw/build/20261002T191829Z-current.XRjUI3/` preserves
compile identities and complete logs. Root build/output products are published
with this report. Frozen milestones and protected Pain archive were not changed.

## Bounded acquisition and postflight

First dashboard showed Master local time valid and both links usable; Slave
locks were still starting. Its initial tee failed because raw/observe had not
yet been created. That stdout dashboard is NOT a persisted raw capture and
its driver RC1 is not a hardware verdict. The strict wrapper then created its
directories and all following logs were saved. Do not invent the missing log.

- First20s strict smoke:22rows,21rejected, no entry, zero qualified hold;
  this includes coarse/startup data, not a steady-state phase diagnosis.
- The ONE allowed120s acquisition observation:130rows,68trusted/62rejected,
  CKO−582..+3222ps,13fresh strict<60ps entry observations. Maximum contiguous
  qualified span2102ms, not300s. No reset/transport errors and no trusted
  pointwise VALID observation outside retention.
- Persisted post-acquisition dashboard: both links usable, all five Slave PLL
  lock gates1, Master valid; Slave WAIT_OFFSET_STABLE,−87ps, invalid time.
- After the timestamp capture, one20s strict postflight:24rows,13trusted/
  11rejected, CKO−2866..+2737ps, no fresh entry and zero qualified hold.
  No reset/transport errors or trusted VALID-outside120 observation.
- Final dashboard: both links and five Slave locks1, Master valid; Slave
  SYNC_PHASE,−2891ps, TIME_VALID/PPS_VALID0.

The predefined postflight extension gate failed; therefore no full300s strict
capture was started. Rejected rows/gaps remain rejected. These sampled checks
do not prove cycle-atomic validity/offset consistency or uninterrupted history.

## Complete same-producer timestamp snapshot

`raw/observe/20261002T192322Z-four-timestamps.log` contains ONE frozen history,
snapshot1,16records,serial/UCNT179..194,15consecutive update pairs. First2pages
passed smoke; the SAME snapshot was extended to16. Actual total177061ms,
queries5578..176559ms, below360000ms. Every record has the same remote source,
domain/port, WR init2 and SPLL init1. Sync and DelayResp sequence IDs are
independent; missing sequence numbers do not invalidate consecutive UCNT.

All full64 raw/calibrated timestamp, fixed-delta, RTT and CKO identities pass;
mean/asymmetry rounding stays within the predefined2ps bound. Fixed deltas do
not change and delayAsymmetry is0. Live bracket health for both boards retained
links, Helper, Slave Main/PSTAT locks and Master local validity; reset signature
remained `{1 1 1 0 1}`. Slave validity is not required for acquisition diagnosis.

Formal data verdict: **PASS_COHERENT_TIMESTAMP_DATA_ONLY**. Laptop independently
decoded the returned raw and obtained the identical analysis JSON. This is NOT
Step6 PASS, analogue skew validation or a causal hardware diagnosis.

Ranges, in ps:

| Quantity | Minimum | Maximum |
|---|---:|---:|
| CKO | −2016.510 | +3731.491 |
| DMS | 173562.500 | 177908.493 |
| raw forward T2−T1 | 175910.995 | 178320.999 |
| raw return T4−T3 | 172686.996 | 181890.991 |
| raw RTT | 350324.982 | 359016.983 |

Two especially useful consecutive transitions have NO preceding or current
phase action: SETP before/after1617ps and phase-write count58 in UCNT192,193,194;
fixed corrections, WR init and SPLL init also remain unchanged.

| UCNT | Δraw forward | Δraw return | Δraw RTT | ΔDMS | ΔCKO |
|---|---:|---:|---:|---:|---:|
| 192→193 | +280.014 | −8162.994 | −7882.980 | −3940.994 | −4221.008 |
| 193→194 | −323.013 | +8272.003 | +7948.990 | +3973.999 | +4297.012 |

Thus the ~4.2ns CKO jumps are algebraically associated with ~8.2ns return-leg
jumps, not a changed fixed delay or a preceding WR phase-write in these pairs.
UCNT189→190 also jumps+3697.998ps with no PRECEDING phase action, but UCNT190
then applies+1865ps as a reaction; do not call that entire pair action-free.
The16records contain5post-state TRACK and11WAIT; numerical mapping remains
3=SYNC_PHASE,4=TRACK_PHASE,5=WAIT_OFFSET_STABLE.

"raw" here means before WR fixed-delta correction. Standard parsing already
handled PTP correction fields; it is NOT a raw OOB/coarse hardware descriptor.
The source adds DelayResp correctionField to its wire receiveTimestamp before
the WR wrapper. Therefore this snapshot cannot separate Master RX linearization
from wire-body/correction-field provenance. Console output may perturb scheduling;
the history was frozen before page output, and no cross-board atomicity is claimed.

## Interpretation / next useful boundary

**STRICT_OFFSET_TIME_VALID_300S=NOT_ESTABLISHED.** Historical TIME_VALID-only
milestones remain historical; the new strict condition has not been met.
The root safety gate still revokes validity rather than concealing excursions.

The next useful inspection is the return timestamp provenance: match Master's
DelayReq RX coarse/ahead/phase/active calibration and linearized timestamp to
the Slave's matching DelayResp wire T4/correction field and this producer's
accepted T4. Preserve full seconds/scaled-ns and independent sequence identities.
First establish an overlapping immutable capture window; do not join two
unrelated console histories or adjust Ki/divisors at the same time.

Master's default2389ps T24P is still unmeasured. Source explicitly requires
Master calibration while running as Slave. This is a candidate boundary, NOT
proof that2389 is wrong; do not copy Slave calibration or run the unbounded
legacy calibration command on the live Master. A calibration intervention must
have a separate bounded/role-correct workflow after provenance evidence.

All98transferred files passed SHA256 on Laptop; the original archive SHA256 is
6e909ef75f9fb35e9622058da65e2d65604605d8b2cf8101971fe336fb472042.
`raw/TRANSFER_SHA256SUMS` records their exact original paths/bytes. No JTAG reader
or programmer remained running after the postflight. No production tuning was
automatically applied at the end of this diagnostic round.
