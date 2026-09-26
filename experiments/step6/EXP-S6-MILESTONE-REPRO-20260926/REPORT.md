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
correction sign. It is not enough to conclude that the phase actuator reached
its target, because this capture did not include the F4L phase-shifter-current
publication. Offset remained outside the 60 ps timing-output gate, so
`TIME_VALID` remained 0.

Raw capture SHA-256:

```text
4820735a9d22082f8ca20347636dee5c8fcc40f03986b364812d404c262ca4d5
```

The next diagnostic is a sparse publication-coherent read of the existing F4L
`phase_shift_current`, paired by timestamp with the WR servo setpoint/offset.
The two telemetry groups must remain explicitly non-atomic. No production
control change is justified yet.

## Verification and retained evidence

The frozen-source verifier reported `SOURCE_PACKAGE=PASS` with 3,214 manifest
rows and zero missing or mismatched entries. The dashboard offline suite
passed all 8 tests, the shell syntax check passed, `git diff --check` passed,
and all 38 raw-file entries in `SHA256SUMS` verify. Build, programmer, dashboard, and
JTAG observer logs are retained under `raw/`.

The current dashboard overlay edits are host-side only. They add the source-
mapped WR servo state and signed phase offset to the Slave panel, correct the
displayed `SYNC_TAI`/`SYNC_NSEC` enum names to match firmware, and make live
monitoring immediate even if a 120-second wait variable is inherited. Explicit
`ONCE=1` readiness checks retain the optional host-side maximum. These edits do
not modify the Step 6 hardware image.

## Next action

The next action is to add a sparse read-only F4L phase-shifter-current sample
with publication-coherence checks, then repeat the same already-programmed
image without reset or reprogram. Do not change the production servo until
the trace distinguishes requested setpoint from actual phase-shifter motion.
Keep Step 6A/Step 6B marked not passed until the Slave PTP servo produces
valid stable snapshots and the same-PPS and scheduled-trigger gates are
independently reproduced.
