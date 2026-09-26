# EXP-S6-WR-EXTENSION-FIRST-DISABLE-ATTRIBUTION-20260921

## Verdict

```text
WR_EXTENSION_DISABLE_ATTRIBUTION = PASS
SLAVE_FAILURE_CLASS             = FAIL_WR_HANDSHAKE_WR_S_LOCK_TIMEOUT
STEP6A_GLOBAL_TIME              = NOT_PASS
STEP6B_SCHEDULED_TRIGGER        = NOT_RUN
PROGRAMMING                     = NOT_PERFORMED_BY_DESIGN
POWER_CYCLE                     = NOT_PERFORMED_BY_DESIGN
```

This was a read-only attribution experiment.  It does not establish Global
Time validity and it does not authorize the Step6B dual-board trigger test.

## Provenance and scope

- Branch: `exp/step6-Global-Time-Testing`
- Observer/source commit: `5b1ce7f1`
- Preserved programmed Step6A image: `ec1f25e8`
- Board sampled: `DE5 [1-11.2]` (Slave only)
- Capture: 3 coherent samples, 1 Hz; stopped at the prescribed stable verdict
- FPGA compile/program, PTP restart, mode command, fiber operation, and
  power-cycle were intentionally not performed.

## Evidence

All three samples were transport-valid and unchanged:

```text
timeout_count  = 0
invalid_count  = 0
stale_count    = 0
unstable_count = 0
record_changed = 0
reset_changed  = 0
```

The persistent first-disable record was valid and stable:

```text
PTP_META             = 0x03020409
current pdstate      = 4  FAILURE
current extension    = 2  PTP
SSTAT servo state    = 0
pre-disable pdstate  = 3  PDETECTED
pre-disable extState = 1  ACTIVE

WR_FAILURE_DEBUG     = 0x02028A01
disable_valid        = 1
disable_cause        = 2  HANDSHAKE_FAILURE
PTP state at disable  = 8

WR_LOCK_RESULT       = 0x98D30701
failure reason       = 3  WR_S_LOCK_TIMEOUT
```

The accompanying signal shadows showed a received WR lock indication and a
Slave-present transmit indication, with no signal rejection:

```text
WR_RX_SIGNAL         = 0x10010001  (id 0x1001, count 1)
WR_TX_SIGNAL         = 0x10000001  (id 0x1000, count 1)
WR_SIGNAL_REJECT     = 0x00000000  (reject count 0)
```

The existing Step5 control context remained locked during the capture:

```text
PSTAT_LOCKED         = 1
HELPER_LOCKED        = 1
MAIN_ENABLED         = 1
MAIN_FREQ_LOCKED     = 1
MAIN_PHASE_LOCKED    = 1
BOOT_GENERATION      = 1
CPU_RESET_COUNT      = 1
WR_CORE_RESET_COUNT  = 1
SI_CONFIG_DROP_COUNT = 1
```

## Interpretation

The first-disable evidence identifies the stable boundary as a WR handshake
failure at the Slave-lock timeout.  It is not a protocol-detection timeout:
the valid cause is `HANDSHAKE_FAILURE`, and the source-backed handshake reason
is `WR_S_LOCK_TIMEOUT`.  The current `SERVO_STATE=0`, `pdstate=FAILURE`,
`extState=PTP`, and `TM_VALID=0` are downstream fallback state after the WR
extension was disabled; they are not promoted to the root cause by this
experiment.

This result narrows the next investigation to the WR S_LOCK handshake state
machine.  It does not prove that Step6A can pass, so no Step6B trigger
experiment was started.

## Raw evidence

Raw file: `raw/extdisable-10s.log`

```text
SHA256  CA0EAC3163A83D1C3901C0C043BF937FF558650DF7D134FA7758D637B7DA9A71
lines   36
samples 3
```

