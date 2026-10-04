# WR acquire/24 + track/24: 15-minute settling and same-boot CKO diagnostic

Date: 2026-10-04, Asia/Taipei. Branch: `feat/file_cleanup`.

## Outcome

**Editable build → compile → program → dashboard workflow: PASS.**
**This /24+/24 candidate: TIME_VALID300s NOT_ESTABLISHED.**
Slave remained TIME_VALID0 at15minutes and in all250 trusted fresh updates
over301797ms later in the SAME boot. CKO was−2085..+2986ps; zero fresh values
were inside±120ps or strict<60ps. Five Slave PLL lock flags and link gate
were1 in every trusted fresh row. No automatic retry, different divisor,
power cycle, consultant or milestone promotion followed this result.

The bounded diagnostic completed, but strict continuous-stability coverage
did NOT qualify:309/358 guarded rows (86.3%) and maximum fresh-update gap4296ms
violate the unchanged90%/2000ms coverage rules. The analyzer therefore retains
`INCONCLUSIVE_INCOMPLETE_CAPTURE` for formal CKO300s stability. Trusted
out-of-band readings independently show this boot did not maintain±120ps
at the observed updates. Diagnostic completion is not a precision PASS.

## Production intervention and baseline limits

Actual firmware/Quartus build source:
`6eb0c2c13d2e7ded49c9b765a153c7124c796384`.
Only two production expressions changed in
`vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c`:
SYNC_PHASE acquisition `/2→/24`, TRACK_PHASE correction `/12→/24`.
The3110 historical qualified inputs plus7 inert declarations were audited;
all other production inputs are unchanged. Thresholds remain60/120ps, with
original wait retries and timing-output validity semantics. No SoftPLL PI,
DAC/bootstrap/arbiter/calibration/PHY/reset/RTL/SDC changes. Integer division
still truncates toward0; slower actuation does not remove measurement noise.

Pain initially had uncommitted acquire/12+track/12 code and derived products.
Those edits were preserved in a scoped Git stash and
`raw/preexisting-pain-local-changes.patch` BEFORE pulling the Laptop candidate.
They were not overwritten or included in this build. The previously running
image's identity is not established by those source edits; do not use it as a
controlled /12 hardware baseline. Unbuilt passive RXTS work is separately
stashed on Laptop and excluded. One boot versus historical boots cannot
establish a deterministic causal effect of the division change.

## Execution chronology

All times below are local wall clock, not inferred firmware-boot time.

| Event | Observed time/result |
|---|---|
| Main-root pipeline started |14:35:06|
| Master/Slave full compile finished |14:39:33/14:51:18, successful|
| Slave programming |14:51:45–14:51:59, successful|
| Master programming |14:52:03–14:52:18, successful|
| Post-program settling |14:52:18→15:07:18,900s, no JTAG/control writes|
| First dashboard |15:07:28: Master valid; Slave WAIT/CKO−1423ps/TIME0|
| Mode1 smoke |15:07:53–15:07:57: all5 frames crossed publication boundary|
| Existing mode2 smoke |15:11:35–15:11:57:17 trusted fresh updates/TIME0|
| Same-boot diagnostic |15:18:29→15:23:33 approximately; reader DONE303571ms|
| Final dashboard/session end |15:23:43/15:23:44: Slave WAIT/CKO−1686ps/TIME0|

The long capture begins approximately26minutes after programming, not exactly
at15minutes: host-only reader/audit corrections were made between the initial
check and this capture. There was NO intervening programming/reset. This run
tested the requested15-minute check and a later26–31minute window. The
wall-clock gap between them must not be interpreted as a continuous capture.

## Trusted observations

| Capture | Raw / guarded / unique | Trusted span | CKO range | TIME_VALID1 |
|---|---:|---:|---:|---:|
| Mode1 smoke |5 /0 /0|0ms|Not assessed|Not assessed|
| Mode2 smoke |24 /19 /17|19449ms|−1820..+3124ps|0/17|
| Long mode2 diagnostic |358 /309 /250|301797ms|−2085..+2986ps|0/250|

Long capture:49 publication/context-invalid rows rejected,59 repeated UCNT
rows excluded from fresh statistics; no STOP/error, identity change, regressed
UCNT or inconsistent repeated-UCNT payload. Boot/CPU-reset/WR-reset/SI-drop
identity stayed `1/1/1/1` in trusted data. Healthy fresh rows250/250.
States: WAIT_OFFSET_STABLE228, SYNC_PHASE22, TRACK_PHASE0. SETP140..546ps;
DMS171277..176042ps. CKO median−1526ps, peak-to-peak5071ps, stddev≈1701.27ps.
The descriptive fitted slope≈+4.98ps/s is NOT physical oscillator drift or
a jitter measurement: observations include state changes and non-atomic groups.

Mode1's rejected frames are preserved as INCONCLUSIVE. Existing mode2 reads
separately epoch-guarded frames and joins them by equal UCNT. Host amendments
`5b4926fc`/`ce7db061` changed no production image or epoch/reset/UCNT guards.
The latter separated usable guarded diagnostics from the ORIGINAL stricter
stability gate. The initially stopped mode2 wrapper and its old classification
remain in `raw/after-settling-mode2-session.log`; the final extension is
separately logged, not a retroactively relabeled run.

The mode2 CKO frame is usable while Global-Time coherence is0 because Slave
TIME_VALID0. This does not permit a Global-Time PASS. No separate300s
TIME_VALID verifier ran without valid entry. Final Master TIME/PPS1,
TAI1878/cycles124999999; Slave TIME/PPS0, no valid TAI/cycle snapshot. Master
dashboard validity alone is not a formal300s qualification.

## Workflow delivered and tests

After editing main code:

```sh
cd /home/b10504072/04_WR
bash scripts/run_current.sh
```

For post-program settling:

```sh
POST_PROGRAM_WAIT_S=900 bash scripts/run_current.sh
```

Default dashboard is continuous; use Ctrl+C before another run. This test used
`ONCE=1 CLEAR_SCREEN=0` for a durable one-shot dashboard. Existing build_current,
compile_current, program_current and step1_6_dashboard remain individually
callable. The pipeline lock prevents overlapping main-root workflows; each
failure stops before later stages.

Editable root mode removes fixed firmware/SOF/SOURCE/PUBLISHED SHA verification
and permits uncommitted production edits. Compilation success, nonempty SOFs
and JTAG ownership remain required. Hashes are GENERATED as provenance, not
used as the user's editable workflow acceptance gate. Frozen workflows stay
pinned; no successful milestone/archive was promoted or overwritten.

Laptop and Pain Python tests29/29 each; native actual-servo tests42cases with
UBSan passed, including unchanged60/120ps behavior and signed /24 division.
Fresh firmware, both full compiles and both programmers succeeded. Timing
closure remainsNO and is not this functional target's acceptance gate. Native
build records retain the actual production build source, rather than claiming
a later observer/documentation commit was compiled.

## Artifacts and independent audit

Fresh SOFs retained in root `output/` and published with this report:

| Role | SHA256 |
|---|---|
| Master |`9f3ee3cb06a0d4c3ad3f7f69c7471984fd6dfe7b2409cd153a7f5379b3a33d45`|
| Slave |`88efdcb9470e7c7fd18a1b677946926397e7ceea8728ddc375aa78a7e3313bfc`|

`raw/pipeline/20261004T063506Z/pipeline.log` records the complete workflow.
`raw/build/20261004T065122Z-current.IL2miW/` retains compiler/firmware identities;
`raw/program/` retains successful programming logs; `raw/observe/` retains
smokes,303s capture and final dashboard; `analysis/` retains guarded summaries.
All30 transferred raw/analysis files passed byte-level verification on Laptop
(`TRANSFER_FILES`, `TRANSFER_SHA256SUMS`). Product-bundle transfer was separately
verified. Products are copied, not rebuilt or relabeled on Laptop.

Laptop independently recomputed all three captures: integer/count/range/guard/
verdict fields matched; descriptive floats matched to1e-9 absolute tolerance
across Python versions. Original mode1 JSON uses the earlier schema without
`diagnostic_capture_complete` and is preserved. See
`raw/tests/laptop-recompute.log`. No rejected frame or duplicate update counted
as fresh evidence. `/home/b10504072/04_WR_archive_step6_pass/` was untouched.
Canonical Step6 source/SOFs remain the prior qualified package, not this candidate.

## Interpretation and stop

On this boot, /24 correction and a15-minute wait did not create valid WR time;
the later5-minute diagnostic still showed ns-scale offset excursions. Do not
treat slower gain alone as a solution, or infer physical DE5a jitter, timestamp
corruption or a defective PLL from these non-atomic observations. This is a
negative candidate result, not a new Step6 milestone. No experiment follows
automatically. Further work should separate timestamp/calibration/runtime-phase
contributions with source-proven guards or use a matched-baseline comparison,
while preserving this result and the unchanged validity/threshold criteria.
