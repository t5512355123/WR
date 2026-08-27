# EXP-WRPC-STEP4-BOOT-GENERATION-PERSISTENCE-DIAGNOSTIC-20260827

## Purpose

Test whether the observed `build_init_readcmd_p` anomaly is associated with a
CPU/core reset and whether the fixed `.debug_precrt` storage persists across
that reset without FPGA reconfiguration. This is a diagnostic-only change.

## Boundary and stop rule

- Keep the Master init command as `mode master;vlan off;ptp stop;ptp start`.
- Do not change the fault handler, IRQ path, SoftPLL, DMTD, RAM implementation,
  PTP/PHY logic, or reset functional logic.
- Add only the CRT boot sentinel, generation counter, four-entry `p` history,
  and the JTAG reader.
- If a natural run shows `BOOT_GENERATION=1` while `_entry` records the `+12`
  value, stop this diagnostic line; the CPU-restart hypothesis is weakened.

## Instrumentation

The fixed `.debug_precrt` layout is:

| Byte address | Word |
|---:|---|
| `0x0002e010` | `p` raw at reset entry |
| `0x0002e014` | `p` raw after BSS/data initialization |
| `0x0002e018` | `BOOT_MAGIC` (`0x424F4F54`) |
| `0x0002e01c` | `BOOT_GENERATION` |
| `0x0002e020..0x0002e02c` | `P_AT_ENTRY_HISTORY[0..3]` |

On a fresh FPGA configuration, the first `_entry` should set generation 1.
If the CPU restarts while the FPGA remains configured, the next `_entry` should
increment the same storage to generation 2 or higher and record another `p`
sample in the ring.

## Reproducibility record

To fill after execution:

- Git commit:
- Master/Slave firmware build result:
- Master/Slave SOF SHA256:
- Master/Slave programmer checksum:
- Timing WNS/HNS:
- Immediate sample log:
- Settled/natural-run sample log:
- Interpretation:

## Raw logs

Raw command output for this experiment is stored below:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-BOOT-GENERATION-PERSISTENCE-DIAGNOSTIC-20260827/`
