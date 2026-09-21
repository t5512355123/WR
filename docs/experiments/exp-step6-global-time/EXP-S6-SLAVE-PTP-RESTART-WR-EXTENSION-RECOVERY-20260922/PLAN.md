# EXP-S6-SLAVE-PTP-RESTART-WR-EXTENSION-RECOVERY-20260922

## Purpose

Determine whether one fresh Slave PTP restart is sufficient to re-arm the
White Rabbit extension and recover the Step6A Global-Time source. This is a
diagnostic recovery experiment, not Step6B scheduled triggering.

## Contract

- Do not compile, build firmware, program either board, reset either board, or
  power-cycle Pain.
- Do not send a mode command. Do not change fiber/QSFP, polarity/bit-slip,
  autonegotiation, SI5340, MDIO, PHY, RTL, or control parameters.
- Before any write, collect five paired Master/Slave samples.
- If the paired gate is not stable, stop with
  `INCONCLUSIVE_PRE_RESTART_STATE_CHANGED` and do not restart PTP.
- If the gate passes, send exactly once on Slave:
  `ptp stop\n`, a 100 ms deterministic gap, then `ptp start\n`.
- Master receives no command. No second restart is allowed.

## Pre-restart gate

Master must remain link-ready with `PTP_STATE=6` and `TIME_VALID=1`.
Slave must remain link-ready with `PTP_STATE=9`, `PD_STATE=4`,
`EXT_STATE=2`, `WRC_MODE=3`, `TIME_VALID=0`, and the already validated
SoftPLL-ready state (`SPLL_SEQ_STATE=8`, Helper/PSTAT/Main locks all true).
Boot, CPU-reset, WR-core-reset, and SI-config-drop counters must not change.

## Recovery observation

Capture both boards for at most 30 seconds after the final `ptp start` newline.
The first sample should be within 1 second. Stop immediately on transport/read
failure, reset change, or unhealthy capture. Treat PTP/lock counter clearing at
the restart boundary as expected by rebasing observer counter deltas after the
final start.

The recovery path is considered formally successful only when:

1. Slave shows `EXT_STATE=ACTIVE` and a non-idle WR state or fresh
   `SLAVE_PRESENT` transmission within 10 seconds.
2. Master shows fresh Slave engagement within 10 seconds.
3. The pre-existing Slave SoftPLL-ready state is not disturbed for three
   consecutive bad samples.
4. At least five consecutive Slave samples have valid/stable snapshot data:
   `TIME_VALID=1`, snapshot valid/time-valid/PPS-valid all true, and the
   snapshot counter advances at least twice.

## Stop/result mapping

The Tcl observer emits the stop result and raw samples. The offline analyzer
is authoritative for the report verdict:

- `PASS_SLAVE_PTP_RESTART_WR_EXTENSION_RECOVERY`: Step6A-1 partial pass;
  Step6B remains not run.
- `FAIL_SLAVE_PTP_RESTART_DID_NOT_REARM_WR_EXTENSION`: no WR re-arm by 10 s.
- `FAIL_SLAVE_REARMED_MASTER_NOT_REENGAGED`: Slave re-armed but Master did
  not re-engage by 10 s.
- `FAIL_SLAVE_PTP_RESTART_DISTURBED_SOFTPLL_READY_STATE`: existing lock was
  disturbed without an FPGA/CPU reset.
- `FAIL_WR_HANDSHAKE_REARMED_BUT_GLOBAL_TIME_NOT_RECOVERED`: handshake
  re-armed but Global Time remained invalid.
- `FAIL_TRANSIENT_GLOBAL_TIME_RECOVERY`: time became valid but did not meet
  the five-sample/advancing-counter gate.
- Any transport/reset/read invalidity is inconclusive, never a fabricated
  Step6 pass.
