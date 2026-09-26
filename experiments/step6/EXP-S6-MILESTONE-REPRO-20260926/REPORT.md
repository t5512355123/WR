# EXP-S6-MILESTONE-REPRO-20260926

## Verdict

```text
STEP6_MILESTONE                  = NOT_PASS
FROZEN_SOURCE_PACKAGE            = PASS
MASTER_CLEAN_BUILD               = PASS
SLAVE_CLEAN_BUILD                = PASS
MASTER_PROGRAM                   = PASS
SLAVE_PROGRAM                    = PASS
STEP5_300S_DIRECT_LOCK_WINDOW    = PASS
STEP6A_GLOBAL_TIME               = NOT_PASS
STEP6A_SAME_PPS_CONSISTENCY      = NOT_RUN
STEP6B_SCHEDULED_DUAL_BOARD      = NOT_RUN
PHYSICAL_SMA_EDGE_SKEW           = NOT_EVALUATED
```

The Step 5 direct-lock gate passed over the complete 300-second requirement.
The first inactive Step 6 boundary is the Slave WR PTP servo's phase-stability
gate. The Slave link and PTP traffic are healthy, but the servo remained in
`WAIT_OFFSET_STABLE`; its signed master offset never entered the source-defined
60 ps window, so timing output and `TIME_VALID` remained disabled. This
reproduction satisfies the Step 5 lock-duration gate, but not Step 6A, and is
not a Step 6 milestone pass.

## Provenance

```text
BRANCH=feat/file_cleanup
PAIN_REPOSITORY_CHECKOUT=600bba9ed48aae5ad5d4a4faa63df609a6d0883b
SERVO_OBSERVER_SOURCE_COMMIT=2d7b5a78c8563140dc28c6dc7ceb1c2b9167f1f2
HARDWARE_SOURCE_ORIGIN=74dc28862653d306e0450cf437ba6d3a230d979d
DASHBOARD_OVERLAY_ORIGIN=3b3a8ec52668d0c60550451ef1780539f7c93fd7
PAIN_WORKTREE=/home/b10504072/04_WR/pain-worktrees/step6-milestone-repro-20260926
QUARTUS=17.0.0 Build 595 Standard Edition
POWER_CYCLE=NO
FIBER_OR_QSFP_CHANGE=NO
```

The frozen-source verifier passed with 3,214 manifest entries and zero missing
paths, SHA mismatches, Git-blob mismatches, relocation-transform mismatches,
package checksum mismatches, or missing required inputs. The independent build
was run from `artifacts/milestones/step6_global_time/source/`, not from the
mutable repository root.

## Build and programming

Quartus completed full compilation successfully for both boards. Firmware MIF
hashes match the historical Step 6 candidate:

```text
MASTER_MIF_SHA256=00cf52190ae60392fce14fcb23ffac6adcb82b3a9ca4de5d1e968d21e3c68681
SLAVE_MIF_SHA256=066761f51af3cc279923bd1e349b33d2d311faa7d2fa23e43745d9a1da3ca33c
MASTER_SOF_SHA256=0780f63d426a1a5deca8fecd56130d7ca343754e6c62c44a8bafd4bee2cc3ae3
SLAVE_SOF_SHA256=60de5a1c6ef31f78ec7b4e132504d0f95a87fcc2ef04ce46acc310784a3d6039
```

Program order was Slave `DE5 [1-11.2]`, then Master `DE5 [1-11.1]`. Both
programmer logs report one device configured, zero errors, and zero warnings.
The rebuilt SOF hashes differ from the historical SOF hashes; this is recorded
as a new independent build, not substituted with the historical binaries.
Timing closure remains `NO` and is not a Step 6 functional acceptance gate.

## Runtime observations

The post-program dashboard invocation explicitly used
`WAIT_FOR_GLOBAL_TIME_SECONDS=120`. It waited about 121 seconds because this
optional host-side readiness gate was configured with a 120-second maximum;
the FPGA has no corresponding 120-second startup delay from this setting. A
separate 600-second host wait was stopped after its 313-second sample; Slave
Global Time was still invalid. The dashboard default is `0`, and the current
continuous-monitor script now ignores an inherited nonzero wait so every live
sample is shown immediately. Only an explicit `ONCE=1` invocation uses the
optional one-shot readiness gate.

Across the 180-second paired late-recovery capture:

```text
Slave CORE_TM_LINK_UP=1
Slave CORE_LINK_OK=1
Slave WR_RX_READY=1, WR_TX_READY=1, WR_RX_LOCKED_TO_DATA=1
Slave STATUS_TIME_VALID=0 throughout the captured interval
Slave snapshot valid/time-valid/PPS-valid=0
TIME_VALID_RISING_EDGES=0
RESET_CHANGED=0
```

PTP RX/TX counters and the WR servo update counter advanced. The latest
source-attribution samples showed `PTP_STATE=9`, `SERVO_STATE=3` or `5`, and
the direct Step 5 signals asserted:

```text
HELPER_LOCKED=1
MAIN_FREQ_LOCKED=1
MAIN_PHASE_LOCKED=1
MAIN_LOCKED=1
PSTAT_LOCKED=1
```

The 360-second direct-lock tail capture contained 189 consecutive valid Slave
samples from `ELAPSED_MS=0` to `359311`, with no sample gaps, no link/capture
or reset violations, and all five checked lock fields asserted in every
sample. The boot/reset signature was unchanged. The offline result is
`STEP5_DIRECT_LOCKS_300S=PASS`; this is a reproduction of the requested
Step 5 runtime gate, independent of the separate Global-Time failure.

The PTP restart replay was protected by the existing five-pair preflight
contract. Master satisfied its time-valid gate, but Slave remained at
`PTP_STATE=9 / PD_STATE=3 / EXT_STATE=1`; the restart contract requires
`PD_STATE=4 / EXT_STATE=2`. It therefore reported
`S6_PTP_RESTART_INJECTION_RESULT=NOT_PERFORMED`. No `ptp stop` or `ptp start`
command was sent.

The follow-up 60-sample read-only trace confirmed the same runtime boundary:
Slave remained `PPS_SLAVE` (`PTP_STATE=9`), WR protocol detection was
`PDETECTED` (`PD_STATE=3`), and the WR extension remained active
(`EXT_STATE=1`). Parent-is-WR, parent-calibrated, local WR mode-on, and parent
mode-on were all 1; local WR state was `WRS_IDLE`, consistent with the
steady state after the WR link-on handshake. Step5 was `LOCKED_SAMPLE` in
60/60 trace samples. Thus this evidence does not support a PHY/link failure,
or the earlier terminal PTP-fallback diagnosis, as the current immediate
boundary.

## Source-backed failure boundary

The WR servo source defines
`WRH_SERVO_OFFSET_STABILITY_THRESHOLD=60 ps`. In
`WRH_WAIT_OFFSET_STABLE`, timing output is enabled only when the absolute
phase-only offset is below 60 ps; after repeated misses the servo returns to
`WRH_SYNC_PHASE` and retries. The observed Slave alternated between those
states without asserting `TIME_VALID`.

The separate 10-sample CKO/SETP time-series capture reported the signed `CKO`
offset and servo setpoint (`SETP`) values below. Firmware publishes `CKO`
from `offsetFromMaster` in picoseconds at the source-mapped Wishbone address
`0x00100A40`:

```text
CKO ps:  +1291, +1046, +1259, +1092, -3402, +699, -3572, -3430, -3448, -3410
SETP ps: 599 through sample 12; 1691 from sample 13 onward
```

No sample was within the required 60 ps bound. The immediate failure is
therefore established: `WRH_WAIT_OFFSET_STABLE` cannot enable timing output
until this signed offset is below 60 ps. This does not yet explain why the
phase-adjustment loop continues to miss the window. Source review confirms
that `WRH_SYNC_PHASE` adds `offset_ps` to `cur_setpoint_ps` and calls
`adjust_phase()`, then retries after ten misses; the current sparse data do
not prove whether the remaining issue is correction direction, phase-actuator
response, timestamp/delay input, or startup/history dependence. Do not change
that control path based only on these samples.

No production control, threshold, timeout, firmware, RTL, reset, or
timing-constraint change was made.

The earlier 60-sample time series gave 0/60 `FRAME_VALID` samples, so those
individual diagnostics cannot be treated as atomic causal pairs. Its
descriptive summary is: servo state 5 in 55/60 samples and state 3 in 5/60;
`CKO` ranged from -3702 to +2518 ps (median +1135 ps), with 0/60 inside the
60 ps gate; `SETP` changed eight times among values from -1747 to +1888 ps;
and Step5 remained locked in 60/60 samples.

### Coherent servo-pair follow-up (2026-09-27)

The read-only observer/analyzer update was pushed as source commit
`2d7b5a78c8563140dc28c6dc7ceb1c2b9167f1f2` and run on Pain against the
already-programmed image. It brackets `SSTAT`, `CKO`, and `SETP` with the
existing firmware servo update counter, rejects changing payloads at a
repeated counter, and makes no production register writes. The capture ran
for 120 seconds on Slave `DE5 [1-11.2]`:

```text
SAMPLE_ROWS                         = 205
READS_VALID                         = 205
COUNTER_STABLE_ROWS                 = 194
ADJACENT_UPDATE_PAIRS               = 104
SKIPPED_SERVO_UPDATES               = 5
SAME_COUNTER_PAYLOAD_CONFLICTS      = 0
SETPOINT_OFFSET_MATCHES             = 11 / 93 tested pairs
POST_ACTION_OFFSET_SAMPLES          = 11
CKO_PS_RANGE                        = -3677 .. +2473
COHERENT_ROWS_ABS_CKO_LT_60PS       = 0 / 194
TIME_VALID                          = 0 / 205
RESET_CHANGED                       = 0
WISHBONE_TIMEOUTS / INVALID_READS   = 0 / 0
```

For all eleven matched actions, the immediate CKO movement sign opposed the
measured action offset. Eight responses reduced the absolute residual; three
overshot and increased it. Examples include `-3359 -> +2132 ps`, `+2393 ->
+1048 ps`, and the overshoots `+1210 -> -3146 ps`, `+965 -> -3454 ps`, and
`+1275 -> -3525 ps`. This is evidence against a globally reversed software
correction sign. At the end of this capture it was not enough to conclude that
the internal SoftPLL phase-shift state reached its target, because F4L current
was not yet observed. Offset remained outside the 60 ps timing-output gate,
so `TIME_VALID` remained 0.

Raw capture SHA-256:

```text
4820735a9d22082f8ca20347636dee5c8fcc40f03986b364812d404c262ca4d5
```

The planned next diagnostic at that point was a sparse publication-coherent
read of the existing F4L `phase_shift_current`; its results are recorded next.
No production control change is justified by that capture.

### Sparse F4L phase-shift-current follow-up (2026-09-27)

The observer source was pushed in commit `d95a8a266310e79df3278de1239100dd3dd75bb0`
and run against the already-programmed Slave image for 120 seconds. The Pain
worktree remained at HEAD `2d7b5a78c8563140dc28c6dc7ceb1c2b9167f1f2`; the observer,
analyzer, and test files from `d95a8a26` were staged there for this read-only
run. No FPGA build, programming, reset, or register write occurred.

```text
SAMPLE_ROWS                         = 201
READS_VALID                         = 201
COUNTER_STABLE_ROWS                 = 191
ADJACENT_UPDATE_PAIRS               = 99
SKIPPED_SERVO_UPDATES               = 7
SAME_COUNTER_PAYLOAD_CONFLICTS      = 0
F4L_FRAMES_VALID                    = 23 / 23
F4L_SERVO_COUNTER_MATCHES           = 20 / 23
COHERENT_SAME-UPDATE_COMPARISONS    = 18
CURRENT_WITHIN_1PS_OF_SETPOINT      = 15 / 18
TIME_VALID                          = 0 / 201
PPS_VALID / LINK                    = 201 / 201
RESET_CHANGED                       = 0
WISHBONE_TIMEOUTS / INVALID_READS   = 0 / 0
SERVO_STATE                         = WAIT_OFFSET_STABLE 183 / 201;
                                      SYNC_PHASE 18 / 201
```

The derived internal phase-shift current ranged from `-1690` to `+2247 ps`
(`-1730` to `+2301` raw units). In 15 of 18 timestamp-associated coherent
rows it was within 1 ps of the firmware servo setpoint. The three larger
differences (`+3236`, `+386`, and `-2171 ps`) occurred at sparse target-change
transitions; the next sampled frame in each observed transition had converged
to within 1 ps. Because sampling is about every 5.4 seconds, this does not
measure the exact settling time.

The WR offset still ranged outside the source-defined `<60 ps` gate in every
counter-stable sample (`CKO=-3816..+2511 ps`), and `TIME_VALID` never asserted.
The read is therefore descriptive and does not pass Step 6A.

Source review bounds what this observation proves: `wrpc_adjust_phase()` calls
`spll_set_phase_shift()`, which updates the internal `phase_shift_target`; the
SoftPLL update loop advances `phase_shift_current` toward that target and
adjusts its internal `adder_ref`. The F4L value is this internal SoftPLL state,
not a direct electrical measurement of output-clock phase. The result rules
out a simple failure to accept or internally track most requested setpoints,
but it does not establish that the main PI/DAC or physical timing path moved
the clock by the same amount.

The first offline analysis exposed a representation mismatch: `PAIR_UCNT` is
emitted as decimal by Tcl, while the raw servo counter fields are hexadecimal.
The analyzer now parses each field in its emitted radix and compares numeric
counter values; the offline test uses the actual decimal pair-counter format.
All five `test_step6_servo_phase_pairs.py` tests pass after the correction.

Raw capture SHA-256:

```text
81079f38eab9832474724e5222cf9c8cba9f883f9209607c25c6cd708b5a5269
```

Analysis output:
`analysis/slave-servo-f4l-phase-current-v1-20260927-summary.json`.

The planned F4L branch/PI capture and a subsequent timestamp-delay input
capture are now complete; findings follow.

### Main SoftPLL PI-response follow-up (2026-09-27)

The read-only F4L extension ran on the already-programmed Slave image/session.
The observer/analyzer source was pushed through commit
`861381610f44800db66746df2bfaf8749c5c961f`; no FPGA build, programming,
reset, or register write occurred for this capture. A 12-second smoke passed
with 20 rows, 19 coherent rows, 10 adjacent update pairs, three valid F4L
frames, and zero timeout/invalid/reset events. The 120-second capture reported:

```text
SAMPLE_ROWS                         = 199
READS_VALID                         = 199
COUNTER_STABLE_ROWS                 = 193
ADJACENT_UPDATE_PAIRS               = 110
SKIPPED_SERVO_UPDATES               = 3
SAME_COUNTER_PAYLOAD_CONFLICTS      = 0
F4L_FRAMES_VALID                    = 23
F4L_SERVO_COUNTER_MATCHES           = 15
COHERENT_SAME-UPDATE-COMPARISONS    = 15
MAIN_PHASE_BRANCH / DETECTOR CALLS  = 15 / 15
PHASE_IN_BAND / LOCKED_BEFORE/AFTER = 15 / 15 / 15
DAC_WRITES / CLAMPED / VCO_FROZEN   = 15 / 0 / 0
CKO_PS                              = -3548 .. +2488
COHERENT_ROWS_ABS_CKO_LT_60PS       = 0 / 193
TIME_VALID                          = 0 / 199
RESET_CHANGED                       = 0
WISHBONE_TIMEOUTS / INVALID_READS   = 0 / 0
```

The Main phase-control branch was active in every joined F4L row; the capture
does not support “the Main phase branch never runs” as the cause of the
Slave's inactive Global Time. It also does not prove that the physical output
clock followed the requested phase. Internal phase-shift current tracking and
PI/DAC publication are telemetry, not an electrical phase measurement.

Raw capture SHA-256:

```text
53f6559f5ad324200d7a6cc2a4a679c508c4865e757217129340ae04533432cb
```

Smoke capture SHA-256:

```text
2f75f1c62090260a6bddf312bd0c2397889073d4097d2d06bdacb8a0be0309dd
```

Analysis output: `analysis/slave-servo-f4l-pi-response-v1-20260927-summary.json`.

### Servo timestamp-delay input follow-up (2026-09-27)

The next read-only observer extension added existing `MU`, `DMS`, and `ASYM`
diagnostics to the servo-counter-bracketed sample and retained sparse,
publication-coherent F4L fields. It ran on the same programmed Slave session;
no build, programming, reset, or register write occurred. The 12-second smoke
completed with 18 rows, 15 coherent rows, nine adjacent update pairs, three
valid F4L frames, and zero timeout/invalid/reset events. The 120-second capture
produced:

```text
SAMPLE_ROWS                         = 181
READS_VALID                         = 181
COUNTER_STABLE_ROWS                 = 158
ADJACENT_UPDATE_PAIRS               = 100
SKIPPED_SERVO_UPDATES               = 7
SAME_COUNTER_PAYLOAD_CONFLICTS      = 0
SETPOINT_OFFSET_MATCHES             = 10 / 91 tests
POST_ACTION_OFFSET_SAMPLES          = 9
F4L_FRAMES_VALID                    = 23
F4L_SERVO_COUNTER_MATCHES           = 21
COHERENT F4L/SERVO ROWS             = 20
MAIN PHASE BRANCH / DETECTOR / IN-BAND / LOCKED = 20 / 20 / 20 / 20
DAC_WRITES / CLAMPED / VCO_FROZEN   = 20 / 0 / 0
MU_RAW_RTT_PS                       = 360019 .. 368653
DMS_CORRECTED_ONE_WAY_PS            = 176009 .. 180326
ASYM_PS                             = 0 (all 158 coherent rows)
DMS - ((MU >> 1) + ASYM)            = -4000 ps (158 / 158 rows)
INFERRED T1_MINUS_T2_PS             = -180218 .. -175978
CKO_PS                              = -3704 .. +2417
COHERENT_ROWS_ABS_CKO_LT_60PS       = 0 / 158
TIME_VALID                          = 0 / 181
RESET_CHANGED                       = 0
WISHBONE_TIMEOUTS / INVALID_READS   = 0 / 0
```

The constant -4000 ps difference is not, by itself, evidence of a bad
calculation: source audit shows `MU` is formed from raw timestamp values,
while `DMS` is the corrected one-way delay after timestamp calibration. The
capture establishes that the corrected delay inputs are stable over this
window. The inferred `T1-T2` term is -180.218 to -175.978 ns, while `CKO`
itself is -3.704 to +2.417 ns and remains well outside the `<60 ps` gate. It
does not establish whether the calibration values are correct or a causal
relation between cross-domain snapshots; the separate telemetry groups are
not atomic.

Source audit found existing SNMP GET objects for the four fixed latency
values. The MIB defines them as read-only `Integer32`; `snmp.c` returns
`pp_time_to_picos()` values when the WR extension is active. Their numeric
OIDs are:

```text
delta_txm  wrpcPtpDeltaTxM  1.3.6.1.4.1.96.101.1.5.14.0
delta_rxm  wrpcPtpDeltaRxM  1.3.6.1.4.1.96.101.1.5.15.0
delta_txs  wrpcPtpDeltaTxS  1.3.6.1.4.1.96.101.1.5.16.0
delta_rxs  wrpcPtpDeltaRxS  1.3.6.1.4.1.96.101.1.5.17.0
```

No DE5 management IP is identified in the current Step6 experiment records
examined. The IP literal `192.168.0.112` found there is documented as the
Pain/NFS server, not a board; generic vendor Etherbone example addresses are
not board evidence. No SNMP request has therefore been sent to an assumed or
guessed address.

Raw capture SHA-256:

```text
ece2c72da8865c38b187d71946ca8704fcb3259e70fd0211e9ee12ef9485d6b8
```

Smoke capture SHA-256:

```text
01f6730d7dfbd2f473872a5dab40dc085b1ad03929c4d31ea8c8a3a653e4c127
```

Analysis output: `analysis/slave-servo-delay-input-v1-20260927-summary.json`.

## Verification and retained evidence

The frozen-source verifier reported `SOURCE_PACKAGE=PASS` with 3,214 manifest
rows and zero missing or mismatched entries. The dashboard offline suite
passed all 8 tests; the Step6 servo-pair analysis suite passed all 6 tests;
the shell syntax and `git diff --check` passed. All 43 raw-file entries in
`SHA256SUMS` verify, including the four new smoke/full observer logs. Build,
programmer, dashboard, and JTAG observer logs are retained under `raw/`.

The current dashboard overlay edits are host-side only. They add the source-
mapped WR servo state and signed phase offset to the Slave panel, correct the
displayed `SYNC_TAI`/`SYNC_NSEC` enum names to match firmware, and make live
monitoring immediate even if a 120-second wait variable is inherited. Explicit
`ONCE=1` readiness checks retain the optional host-side maximum. These edits do
not modify the Step 6 hardware image.

## Next action

Read the Slave's active IP using the existing read-only `ip get` firmware
command over the JTAG virtual-UART path, after confirming the exact transport
and reply-capture method. Then, only if that runtime address and SNMP
reachability are verified, issue bounded SNMP GETs for the four OIDs above on
both boards and correlate them with `MU`/`DMS`/`ASYM`. Do not scan the LAN or
guess an address. Keep production controls unchanged. Step 6A/Step 6B remain
not passed until the Slave produces valid stable Global-Time snapshots, the
same-PPS gate passes, and the scheduled-trigger gate is independently
reproduced.
