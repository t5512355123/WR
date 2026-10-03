# Main phase / ptracker progress — actual completed round

**STRICT_OFFSET_TIME_VALID_300S = NOT_ESTABLISHED.**
Data verdict: PASS_POST_ACCEPT_PHASE_DATA_ONLY, NOT Step6 PASS.
No merge/milestone promotion. No power-cycle, advisor, calibration, PI/gain/
threshold/timeout/RTL/reset change. Normal /2 acquisition and /12 tracking.
The frozen milestones and protected Pain archive were not modified.

## Workflow / exact artifacts

Laptop edit/test/push -> Pain exact ff pull/native tests/role firmware build ->
actual hashes returned and pinned on Laptop/push/Pain pull -> full root compile
-> one Slave/Master program pair -> bounded observations -> actual raw/products
returned to Laptop -> independent analysis/report/publication.

Baseline publication fbef317928f4c7717e3a73f76343be449b6f8cb0.
Actual role firmware source6b5be58627e3480d522c5e0e61ebdba3ed0fc8c9.
Actual full Quartus compile source25603ae2f2ff41f0f43ae93a4f9ef2829294a299.
The intervening commit only pins actual tested hashes and precheck documentation.
Firmware/control source therefore identical for role builds and full compile.

| Artifact | SHA256 |
|---|---|
| Master MIF | 8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5 |
| Slave MIF | 08ca140f1f569cefff5bbdcd1cbc932248a73383f8ea7a43a6119864d293b7ad |
| Master SOF | ca29d184d2ff8dc5b7182acc6a405dd8d59f78a9c85d69ce86fc016d143ed1e4 |
| Slave SOF | 4b22351ea15d1c2f9b1631f5f98755a2618d5f701591a511d4e78e2a6b90fbbc |

Both full compiles PASS. Master ended10:15:41, Slave10:27:31 Taipei.
Both timing NO (implementation caveat, not this functional gate).
Reported setup/hold Master+0.192/+0.040ns; Slave−0.659/+0.035ns.
Do not infer full timing closure from these individual slack fields.

One programming pair, no retry: Slave10:28:01–10:28:20, then
Master10:28:20–10:28:39, both successful. Root output retains THESE exact SOFs.

## What changed / what did not

Private reference ptracker metadata records actual init/start generation and
each512-sample averaging completion: coherent epoch, count, publication timer,
raw averaged phase and final-bin reference/input tags. It does not change
averaging, tag ordering, phase calculation, ready semantics, enable commands or
shared-memory struct. Aux IDs outside the reference array are not indexed.

At each actual accepted normal WR E2E calculation, a32-row private history saves
full signed64 CKO/DMS seconds and scaled-ns, WR pre/post SETP, phase-write count,
and independent coherent copies of the latest completed Main and ptracker data.
Two36-word rows/page fit the existing1024-byte VUART FIFO including conservative
echo/CRLF/prompt reserve. Page0 freezes once before console output, remaining
pages read that same RAM. Old TS4/RXTS schemas unchanged.

This is NOT packet-time alignment: Main and tracker are copied after WR update,
not atomically with one another or the earlier T1/T2/T3/T4 events. Ptracker
ready/enabled flags describe its last metadata publication. Last-bin tag pair
is NOT all512 contributing samples. Timer follows the copies to avoid a later
ISR publication looking nearly2^32ms old. No diagnostic data feeds control.

Actual control/build-source diff against baseline is empty for wrh-servo.c,
spll_main.c, firmware/configs, quartus and quartus_generated.

## Tests and bounded execution

Laptop8 history tests, including whole actual Tcl observer success/fault path,
14 TS4 tests and9 strict analyzer tests PASS. Actual Pain native history,
ptracker512-average/publication/seqlock, original TS4,35 strict control cases,
and fixed diagnostic UBSan tests PASS. Initial harness missing-include and
host/embedded assert header collision were fixed on Laptop/pushed/pulled;
their failures remain in raw/tests, not relabeled PASS.

Fresh RAM footprints Master170724 / Slave170684 bytes of196608, unchanged stack.

| Capture | Rows / rejected | Fresh <60ps entries | Best qualified span | Trusted CKO ps |
|---|---:|---:|---:|---:|
|20s startup smoke022930Z|25 /11|0|0ms|−7400..305327048|
|one120s startup023012Z|129 /66|4|603ms|−3811..+2184|
|20s postflight023628Z|23 /6|4|605ms|−236..+133|

All three strict analyses have errors=[] and pointwise valid-outside-retention=0.
Startup coarse synchronization outliers are retained, not mixed into the later
phase-history window or discarded. None meets the predeclared10s extension gate.
No300s capture was started; no claim that300s was tested or passed.
Rejected rows break evidence continuity; they are not interpolated or ignored.

## New actual phase-history evidence

One snapshot, page0 smoke valid, all32 rows complete, elapsed162614ms within240s.
UCNT171–202,31 consecutive WR updates over31311ms of firmware timer.
Bracket health five times per role: both link/clock/reset gates and Slave locks
good; Master validity good; reset signature unchanged {1 1 1 0 1}.
SPLL init counter1, Main frame init_generation1, ptracker generation4 throughout.
Main frame init_generation itself uses SPLL init count, NOT an independent
Main-only reinit counter; the forward update/sample counts provide additional
continuity evidence. No source-copy errors.

| Measurement | Actual result |
|---|---|
| Main completed sample_n | increases119436; progresses in31/31 adjacent intervals |
| Main control branch | PHASE32/32; freq error−19..+16 raw units |
| Main flags | 0x17F32/32: freq/phase lock before/after, phase detector called/in-band, DAC write |
| Main phase error | −411.1328125..+501.953125ps;25/32 outside±120ps |
| Main PI/DAC command |11773..11935; not necessarily applied SI5340 value |
| Ptracker averaging publications | increases234; progresses31/31 |
| Ptracker data age |1..126ms; published ready/enabled flags3 throughout |
| WR CKO |−306.5032958984375..+242.49267578125ps |
| WR offset point samples |8/32 strict<60ps;20/32 inclusive±120ps |
| WR states |WAIT_OFFSET_STABLE20;TRACK_PHASE11;SYNC_PHASE1 |
| Previous WR setpoint action zero |19/31 adjacent differences |

Source-proven units: PHY8bit reference125MHz; DMTD clocks divided2;
HPLL_N14. Main phase-error unit=16000/16384ps. Thus unchanged Main phase
detector threshold1200 corresponds1171.875ps, NOT the requested120ps hold.
MainPhase=1 can legitimately coexist with these errors; the bit is not lying,
it is enforcing a different threshold. Ptracker conversion follows existing
normalized doubled modulo8ns API and retains raw values in the log.

Example action-free193→194→195 at constant WR SETP−6066ps:
CKO−156.51→+120.48→−306.50ps. Main error+11.72→−222.66→+418.95ps.
194→195 gives ΔCKO−426.9867ps and ΔMain error+641.6016ps while2102new Main
updates and4tracker publications occurred. This establishes live residual
phase variation at the sampled endpoints, NOT a single-cycle causal join.
Other intervals do NOT track one-to-one (199→200 Main error changes+741.21ps,
CKO only+1.01ps); no simple correlation is being promoted to proof.

## Interpretation and next single experiment

Within this snapshot, neither frozen Main servicing nor old/unpublished tracker
data explains the failure: both producers continued and ages match a normal
512-sample bin at approximately3814Main updates/s. This does not rule out a
short unsampled stall or the packet-specific timestamp/transition-point issue
seen in prior~4ns-jump boots. The current groups are not packet-aligned.

Crucially, actual Main residual phase is considerably wider than±120ps even
while every sampled detector flag reports phase lock. WR controller Ki is NOT
proven faulty; constant WR SETP also never meant frozen Main DAC/PI.
The old TIME_VALID-only300s milestone used a retained validity latch and did not
prove today's strict offset requirement. Startup/fit/phase branch differences
between boots also remain real uncontrolled state, not grounds to blame a
nonexecuted WR tracking-gain branch.

Next unique control experiment: **Slave Main Kp300→600 only**, retaining Main
Ki1, frequency threshold20, bumpless preload, WR /2+/12 and strict60/120 gate,
all Helper/DCO/service/timeout/topology/RTL unchanged.600 is one of the source's
two explicitly permitted F4K A/B values (300 or600); current default is300.
It is not a new arbitrary gain sweep. Audit the historical600 arm before any
build to distinguish a genuinely new current-baseline test from an already
failed identical configuration. Test whether increased Main
proportional action reduces actual completed phase-error/CKO variation rather
than loosening lock detection. This is a hypothesis, not a promised fix or
proof the present Kp is the cause. Keep the same passive history and independent
strict reader gates. If real error/locking/upstream health worsens or does not
improve, report that result; no gain sweep or automatic Ki change.

No such next control change/build/program happened in THIS round. Publish this
completed evidence first, then follow Laptop edit/test/push -> Pain exact pull/
build/compile/program -> Laptop records/report/push for the next round.

Final one-shot dashboard: Master and Slave TIME_VALID/PPS_VALID1, Slave CKO71ps
and TRACK_PHASE, all five Slave locks1. Sequential PPS snapshots differ and are
not an atomic board-time comparison. This pointwise success is NOT300s PASS.

## Return verification

85actual products/raw/analysis files SHA256 PASS on Pain and Laptop, listed in
raw/TRANSFER_SHA256SUMS. Return archive outside protected paths:
/home/b10504072/wr-transfer-backups/phasehist-return-20261003/products.tgz
SHA2560bee1a8bfd61a7e4b2de69fad1a6d98e96c39ce2eb065a4796441c78ee680b9e.
Independent Laptop analysis reproduces Pain JSON values exactly; host newline
bytes differ, so byte-identical JSON is NOT claimed. Laptop-derived summary and
reanalysis are additional files, not part of the original85 returned files.

Post-capture validator audit added an explicit half-range counter-decrease/reset
rejection; zero progress remains a reported stall, not silently filtered. It
does not change the valid capture's result/rows.9history offline tests now PASS.
This is observer validation only, no new firmware build/program or gain change.
