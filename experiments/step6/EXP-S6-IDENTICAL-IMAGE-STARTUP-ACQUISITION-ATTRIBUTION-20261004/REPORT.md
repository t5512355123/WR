# Same-configuration acquisition diagnosis — live baseline and root replay completed

2026-10-04, Asia/Taipei. This report preserves both successes and the earlier
failed boot; the physical cause of inconsistent initial acquisition remains
unresolved. A successful retry is not a deterministic-startup qualification.

## Current result

`CURRENT_LIVE_TIME_VALID_300S = PASS`; `FRESH_ROOT_REPLAY_TIME_VALID_300S = PASS`;
`FPGA_CONFIGURATION_EXACT_MATCH = PASS`; `DETERMINISTIC_STARTUP = NOT_ESTABLISHED`;
`PHYSICAL_CAUSE_OF_CKO_BOOT_VARIATION = NOT_YET_IDENTIFIED`.

Today a new user-triggered root programming is recorded: Slave ended08:11:07,
Master08:11:26. SOFs33e58bf4/fa5e4d2c are exact qualified main-root artifacts.
The08:16:42 preflight had both TIME_VALID/PPS_VALID1, Slave five locks1,
TRACK_PHASE, CKO−104ps. This is not midnight's failed boot recovering later.

After Laptop observer/analyzer/tests push(fcdb3f6d), Pain exactpull, no build,
programming, reset, control changes or competing reader occurred during this
live-baseline capture. Read-only preservation is intentional: do not destroy
the now-successful boot before recording it. Current root source manifest
418bb254 contains3117 input files; all checked. Milestones and the protected
04_WR_archive_step6_pass path were not modified.

## Formal retention evidence

Raw folder: `raw/20261004T003029Z-live/`. Observer began08:30:29,
formal303s-per-board acquisition used the unchanged TIME_VALID verifier;
complete live wrapper ended08:41:07.

| Board | TIME_VALID rows | observed span | largest gap | complete DONE |
|---|---:|---:|---:|---|
| Master1-11.1 |1190/1190|302900ms|257ms|303155ms|
| Slave1-11.2 |1190/1190|302880ms|257ms|303134ms|

Both PPS/snapshot/link diagnostics1190/1190, live time monotonic. Board
captures are sequential, not proof of simultaneous global-time equality.
No sampled invalid rows; complete sample indexes and DONE counts verified.
Laptop independently reran the analyzer with300000ms/1000ms-gap/301-min-rows
and recovered the identical result. Raw SHA2565af80714; result85c83f0d.

## Source-proven distinction between acquisition and retention

In the actual unchanged wrh-servo.c, WAIT_OFFSET_STABLE enables timing only
when its legacy offset test is strictly<60ps, after the coarse-time guards.
This is the historical C abs()/integer-width policy, not the superseded
strict full64 offset validator. TRACK's>120ps fallback
returns to SYNC_PHASE without clearing the previously enabled timing output.
wrpc_enable_timing_output and the PPS ESCR valid bits retain that state until
an actual disable/reset path. Five SoftPLL lock bits do not enable timing
by themselves. Existing native-C22cases exercise that exact source policy.

15s phase/context smoke:24raw rows,20trusted,4guard rejections,15unique UCNT
updates,0conflicting same-UCNT payloads. All20 trusted health observations
had TIME_VALID1, while15had abs(CKO)>120ps. CKO−516..+412ps; DMS173734..174343ps;
SETP−5444..−5262ps. Unique statesSYNC3/TRACK2/WAIT10. Three consecutive-UCNT
SYNC→WAIT actions matched the actual CKO/2 arithmetic, including negative
truncation. This proves software arithmetic, not physical actuator response.
Health and phase groups are separately sampled, not atomic hardware events.

The earlier independent midnight rebuild had BYTE-IDENTICAL FPGA RBF
payloads yet failed both600s readiness attempts: SlaveTIME_VALID0, five locks1,
WAIT_OFFSET_STABLE and dashboard CKO−2353/−2460ps. Those captures remain
failures of initial acquisition, not failures of300s retention after entry.
Different SOF metadata does not explain them; the RBF configuration is equal.
The new valid boot does not overwrite or reverse those failed outcomes.

## Controlled fresh root replay — completed

Laptop live report/support and exact reference SOFs were pushed; Pain pulled
source `3bf9f3b4151d9e977a7d573d11432d2871fff646`. Replay record:
`raw/20261004T004730Z-replay/`. All3117 production inputs checked before and
after the actual firmware build and full Master/Slave FPGA compiles. Both
firmware MIF pins remain identical to the qualified root. No production C,
RTL, gain, threshold, timing constraint, reset, port or control changes.

| Artifact | SHA256 |
|---|---|
| New Master SOF |2707402e3fb9b7a2a065d0d741ce7f344c0c606ccbf2e8ce104c8056b761a712|
| New Slave SOF |11549fc12a88b98c664ca43d06fa1a571fc5a108b6dd12fc3ba35ecb6a1ec524|
| Master RBF, reference and new |8e5f1ab2c0c44376493f5ff1dedc50c3e6423835e7f96de42ceda96758007f09|
| Slave RBF, reference and new |886650e7345968e1739087d3e82fb054caa31950d0eb0f7657e97b148ba908dc|

Both RBFs are43911564bytes, compared with cmp BEFORE programming. Different
SOF metadata/checksums do not mean different configuration payloads. These
RBFs also match the earlier failed independent milestone rebuild. The new
SOFs and all53 tracked root build/output products are retained/published;
`root-products.tar.gz` SHA256 is
134f06f90755919f0db815b230aacabb8504700a9e92b813264808a9033b9596.

One programming pair only: actual Slave programming completed09:06:05,
Master09:06:24. The wrapper's09:04:12 PROGRAM_BEGIN includes authentication
and job-control wait; it is NOT the actual FPGA programming timestamp. Before
programming, our own runner was deliberately paused while its compile child
finished, allowing a passive readback of the still-live08:11 successful boot.
It was resumed/foregrounded before sudo password entry. No existing user
process was terminated, and no second JTAG owner operated concurrently.

### Initial acquisition, not observer time mistaken for boot time

The existing single-reader startup acquisition observer returned0/DONE,
ending at first TRACK.246 raw rows,222 accepted,23 frame/context rejections,
one same-UCNT conflicting payload rejected;100 unique UCNT updates,121
duplicates and3 skipped intervals. No arithmetic pair bridges a rejection
or skipped update. Unique states: UNINITIALIZED1, SYNC_TAI18, SYNC_PHASE9,
WAIT_OFFSET_STABLE71, TRACK_PHASE1. State4 is TRACK,5 is WAIT, per source.

Health arming took67877ms. First observed valid TRACK row ended at
**159381ms total observer time**, not91155ms acquisition-relative row-start
time and not firmware boot/S_LOCK time. At that row: UCNT0x6D, CKO−43ps,
SETP5973ps, DMS173867ps, TIME_VALID1. Around90s the five lock flags were
already1 while TIME_VALID was0 and CKO+3822ps: lock alone does not open the
WR timing gate. After health arming, sampled phase-labelled CKO was
−11720..+7840ps. Coarse synchronization can still be pending in a
phase-labelled publication; the entire startup's low32 CKO is not a pure
fine-phase jitter measurement.

All five trustworthy adjacent SYNC→WAIT actions matched C offset/2
arithmetic: SETP deltas−1862,+3908,+863,−355,−247ps. Observed SETP range
−1862..+7232ps. This establishes software arithmetic/publication, not actual
physical actuator response. Health and phase groups are not atomic.

### Same-boot 300s qualification

No extra programming, reset, power-cycle or runtime control change followed
acquisition. The unchanged303s-per-board verifier completed; wrapper ended
09:19:23. Each board has exactly one complete DONE and no invalid/error rows.

| Board | TIME_VALID rows | observed span | largest gap | DONE elapsed |
|---|---:|---:|---:|---:|
| Master1-11.1 |1190/1190|302852ms|257ms|303108ms|
| Slave1-11.2 |1190/1190|302870ms|256ms|303124ms|

PPS/snapshot/link1190/1190 per board; live time monotonic. Sequential windows
do not establish simultaneous equality or cycle-by-cycle continuity. Laptop
independently recomputed the complete result and matched the Pain JSON exactly.
Raw SHA256 c7120a8d430f6c5f89d120c5cd56da660d3702dc1b099bc8b3f1399edbe85819f;
result abb383e281c738a222fee6b15d39a8b4f56c74f2324d0f51b5d5ded67a062c98.

### Passive runtime readbacks: equal configuration, different runtime state

Before the new program09:02:39–09:03:03 and after qualification, the existing
readonly VUART reader issued only `pll stat` and `pll gps 0` on both boards.
It saved full raw replies/trailing prompts; no sps/set/calibration/control
commands. The values below are sequential query groups, NOT atomic pairs.

| Field |08:11 successful boot, before replay|09:06 successful boot, after qualification|
|---|---:|---:|
| Master T24P reported ps |2389|2389|
| Master phase-tracker raw phase |2122|6939|
| Slave T24P reported ps |7050|7150|
| Slave phase-tracker raw phase |2690|5971|
| Slave scan rising/falling ps |6800/3300|7300/3000|
| Slave `pll gps 0` current/target ps |−5486/−5486|7811/7811|
| Slave `pll stat` main phase_current raw units |−5611|6011|

Both readbacks show Slave Helper/Main locked, ready, delock0; Master Helper
locked. Different calibrations/phases under the same source/RBF establish
runtime variation, NOT that the100ps T24P difference caused the failure.
The midnight failed boot has no such readback and cannot be reconstructed
after the user's08:11 reprogramming. Do not equate phase_current units with
GPS ps or compare separately sampled values as an instantaneous conversion.

Final dashboard remains TIME/PPS valid with all five Slave locks1 but
CKO−1987ps. Therefore this is sampled TIME_VALID300s PASS, not±120ps accuracy,
300s five-lock qualification or physical PPS edge-skew qualification.

## Additional source risk — not the demonstrated failure cause

The actual CONFIG_WRPC_PPSI `from_picos()` negative branch multiplies signed32
`-ps * (1<<14)` before assigning to uint64. Fresh compiled RV32 disassembly
in `build/from-picos-disassembly.log` confirms MUL followed by sign extension
before division. Negative ps<=−131072 can overflow that product; the positive
branch widens first. This is a real source/compiler boundary, but **zero**
observed unique updates in this replay cross it. The failed boot's SETP is
unknown. No production fix was made and no claim assigns that failed boot
to this bug. Instruction arithmetic modelling is not a hardware test.

## Verification, limitations and next evidence boundary

Pain replay: actual native C22 cases under UBSan,27 then-current Python
source/analyzer tests passed. Laptop final updated analyzer/source tests30
and readonly VUART/transport tests25 passed. Analyzer refinements distinguish
observer/acquisition time and flag the conversion risk; raw Pain analysis is
retained unchanged, with updated independent results under `analysis/`.

All15 live and37 replay transferred files checksum-match. Root products were
restored from a checked archive containing only53 tracked build/output paths;
no frozen milestones or protected archive files were modified.

The causal boundary now supported is **initial WR servo acquisition versus
latched TIME_VALID retention**. Equal images do not imply equal calibration,
phase or startup state. The lost failed boot prevents identifying its exact
physical/runtime cause. A future useful capture must preserve an unfavorable
first acquisition and associate SETP with actual current/target and calibration
readbacks; blindly recompiling/reprogramming or sweeping gains would erase
that evidence. No advisors, forced-valid bit, automatic retry or archive
promotion was used. The inconsistent-startup diagnostic goal remains active.

The canonical Step6 package retains its earlier qualified root snapshot and
honest failed fresh-standalone verdict; this new ROOT replay does not silently
recertify or replace the canonical milestone.
