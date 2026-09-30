# EXP-S6-STARTUP-ADMISSION-BOUNDARY-TRACE-20261001

## Current status

~~~text
VERDICT = PHASE_STATE_REACHED_BOUNDARY_STOPPED
HARDWARE_CAPTURE = COMPLETE
FIRST_INACTIVE_BOUNDARY = NO_SINGLE_INACTIVE_COUNTER_BOUNDARY_OBSERVED
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~

This was a read-only startup/admission boundary trace. It does not test
fixed-SETP phase convergence and is not a Step 6 acceptance run.

## Baseline and scope

See [`PLAN.md`](PLAN.md) for the exact source/SOF baseline, source-mapped
register groups, run protocol, and stop criteria. The only allowed changes are
this observer, its offline tests/analyzer, and experiment records. No
production control, image, PI, threshold, DMS/PTP, RTL, or timing changes are
included.

## Result

### Exact-image Pain run

Pain fast-forwarded to `423c276e7c48724c173498c2259841f9d443eaa0` on
`feat/file_cleanup`. The pinned files were verified before programming and
again identified by Quartus during programming:

| Board | Result | SHA-256 | Quartus checksum |
|---|---|---|---|
| Slave `DE5 [1-11.2]` | Programmed successfully | `13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19` | `0x30B1E229` |
| Master `DE5 [1-11.1]` | Programmed successfully | `697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a` | `0x30B18F28` |

No compile/rebuild was performed. The single Slave observer started immediately
after Master programming; no dashboard or second JTAG reader ran in between.
Capture started at `2026-09-30T17:45:02Z` (`2026-10-01 01:45:02` Taiwan time)
and stopped at the configured state boundary after `56,430 ms`, not at the
300-second duration limit.

### Capture integrity and stop condition

~~~text
STOP_REASON = PHASE_STATE_BOUNDARY
SAMPLES = 39
STRUCTURALLY_TRUSTED = 39/39
HEALTH / ADMISSION / SPLL / EVENTS valid = 39/39 each
WB_TIMEOUT_COUNT = 0
WB_INVALID_COUNT = 0
RESET_CHANGED = 0 for all trusted rows
STEP1_GATE = PASS on 38/39 trusted rows (the first startup row was low)
ROW_SPACING = 1375..1505 ms (requested post-row delay was 250 ms)
~~~

The final trusted row reported `SERVO_STATE=3`, source-mapped as
`WRH_SYNC_PHASE`; the observer therefore stopped exactly at its prescribed
phase-state boundary. This is a boundary observation, not a phase-lock result.

### Startup and event-chain observations

~~~text
TRUSTED_SERVO_STATE_COUNTS = {0: 21, 1: 17, 3: 1}
LAST_ROW: Step1=1 HelperLock=1 MainEnabled=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
MAX_CONTINUOUS_ALL-READY = 2 rows / 1399 ms
STEP5_300S_STABILITY = NOT TESTED
~~~

The five Step 5 lock gates were simultaneously high only for the final two
rows, far short of either the observer's 10-second startup-ready guard or the
project's 300-second Step 5 milestone. Their brief appearance must not be
reported as a sustained Step 5 or Step 6 pass.

The offline analyzer found positive deltas across every examined startup and
event-processing boundary; it did not identify one inactive counter boundary:

| Counter group | Observed delta |
|---|---:|
| WR lock polls / lock enable | `+301,589` / `+1` |
| lock-unlocked / calibration-fail | `+300,473` / `+1,115` |
| SoftPLL state transitions / init / clear-DAC | `+6` / `+1` / `+1` |
| DMTD REF/FB accepted | `+311,529,839` / `+310,838,733` |
| DMTD REF/FB post-CDC events | `+103,465,766` / `+103,079,672` |
| TAG / TRR write / TRR pop | `+194,360` / `+194,538` / `+194,008` |
| IRQ / Helper update | `+188,018` / `+66,619` |

Thus this capture observed activity through Helper updates and a brief interval
with all five lock gates high, but also substantial unlock/calibration-failure
counter growth. Because register groups are separately sampled and are not
atomic, these deltas do **not** establish same-cycle ordering or causal
attribution. The analyzer's result is
`NO_SINGLE_INACTIVE_COUNTER_BOUNDARY_OBSERVED`; the capture cannot by itself
identify why the ready interval was brief.

### Raw evidence and verdict

The raw log and its checksum sidecar are stored under this experiment's
`raw/observe/` directory. Pain's sidecar and the copied laptop file agree:

~~~text
RAW_SHA256 = 2b4b30bb0f76c5286fcaefcbf00f5b936126ab1f1f22b5e1e167df9755d4203d
~~~

Final verdict:

~~~text
STARTUP_TRACE = PHASE_STATE_REACHED_BOUNDARY_STOPPED
INACTIVE_COUNTER_BOUNDARY = NOT IDENTIFIED
LOCK_READINESS = BRIEFLY OBSERVED, NOT SUSTAINED
PHASE_CONVERGENCE = NOT EVALUATED
STEP6_STABLE_OFFSET = NOT ESTABLISHED
~~~

Per the agreed stop rule, no phase smoke or follow-on experiment was started.
A new advisor recommendation is required before any next hardware experiment.
