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

```text
SOURCE_COMMIT=67ee96251192867455e5e155189c8ab352956469
EVIDENCE_COMMIT=3eeb268
MASTER_MIF_SHA256=cf7897a4c7bcb626d017471ed4b239a8fbb032724c60b908fd0d151dfeb9ded0
SLAVE_MIF_SHA256=550e7a328e81bb761fc8f37a6f3a7fbde44a4fedbcedc6b65d489b3547c45de8
MASTER_SOF_SHA256=d505a96633081e3d7cb3e7b1ea52f7d723cd2f70047949e28117b6e0b2145325
SLAVE_SOF_SHA256=4d8c66c749a9b39ec3816a3b117024a0bfcb67f58464cf11b6d856c095d8e833
SHELL_INIT_CMD_ADDR=0x000179A8 (Master and Slave)
BUILD_INIT_READCMD_P_STORAGE_ADDR=0x0001C374 (Master and Slave)
BOOT_MAGIC_ADDR=0x0002E018 (Master and Slave)
BOOT_GENERATION_ADDR=0x0002E01C (Master and Slave)
P_AT_ENTRY_HISTORY_ADDR=0x0002E020 (Master and Slave)
QUARTUS_VERSION=17.0.0 Build 595 04/25/2017 SJ Standard Edition
MASTER_PROGRAMMER_CHECKSUM=0x30B1C0C2
SLAVE_PROGRAMMER_CHECKSUM=0x30B1E32B
MASTER_JTAG_ID=0x02E660DD
SLAVE_JTAG_ID=0x02E660DD
MASTER_TIMING_CLOSED=NO
MASTER_WNS_NS=-0.213
MASTER_HNS_NS=+0.039
SLAVE_TIMING_CLOSED=NO
SLAVE_WNS_NS=-0.239
SLAVE_HNS_NS=+0.039
MASTER_COMPILE=Full Compilation was successful
SLAVE_COMPILE=Full Compilation was successful
```

## Observed results

The reader was run with `settle_ms=0` immediately after programming and then
with `settle_ms=30000`. The reader holds the CPU only after the settle interval;
the FPGA was not reprogrammed between the two reads in each pair.

| Pair | Board | Immediate generation | 30 s generation | Change | `p` at entry | Offset from shell command |
|---|---|---:|---:|---:|---|---:|
| after reprogram | Master | 4 | 7 | +3 | `0x000179B4` | `+12` |
| after reprogram | Slave | 2 | 3 | +1 | `0x000179A8` | `+0` |

Both boards returned `BOOT_MAGIC=0x424F4F54`. The Master history contained
`0x000179B4` entries and the Slave history contained `0x000179A8` entries,
consistent with the pre-main raw samples. A second saved pair before the final
reprogram also showed Slave `4→5` over 30 seconds; Master remained at 9 in
that pair, so the restart rate is not claimed deterministic.

The after-reprogram raw samples were:

```text
Master immediate: GENERATION=00000004 HISTORY0=000179A8 HISTORY1=000179A8 HISTORY2=000179B4 HISTORY3=000179B4 P_RAW_AT_RESET_ENTRY=000179B4 P_RAW_AFTER_DATA_INIT=000179B4
Master settled:   GENERATION=00000007 HISTORY0=000179A8 HISTORY1=000179B4 HISTORY2=000179B4 HISTORY3=000179B4 P_RAW_AT_RESET_ENTRY=000179B4 P_RAW_AFTER_DATA_INIT=000179B4
Slave immediate:  GENERATION=00000002 HISTORY0=000179A8 HISTORY1=000179A8 HISTORY2=00000000 HISTORY3=00000000 P_RAW_AT_RESET_ENTRY=000179A8 P_RAW_AFTER_DATA_INIT=000179A8
Slave settled:    GENERATION=00000003 HISTORY0=000179A8 HISTORY1=000179A8 HISTORY2=000179A8 HISTORY3=00000000 P_RAW_AT_RESET_ENTRY=000179A8 P_RAW_AFTER_DATA_INIT=000179A8
```

## Interpretation

```text
CPU_ENTRY_REEXECUTION_WITHOUT_FPGA_RECONFIGURATION=PROVEN (Master +3, Slave +1 in 30 s)
DEBUG_PRECRT_PERSISTENCE_ACROSS_CPU_RESTART=PROVEN
MASTER_PARSER_OFFSET=PROVEN (+12; 0x179B4 - 0x179A8)
SLAVE_PARSER_OFFSET=PROVEN (+0; 0x179A8 - 0x179A8)
FRESH_PROGRAM_GENERATION_1=NOT_VERIFIED
ROOT_CAUSE=NOT_PROVEN
STEP4_PASS=NOT_CLAIMED
```

The first sample after the recorded reprogram was not generation 1. Because
`.debug_precrt` is `NOLOAD`, this run did not establish a clean zeroed starting
state for the sentinel/counter; it must not be reported as a fresh-generation
pass. The valid conclusion is the within-configuration increase from 4 to 7
and from 2 to 3. This proves CPU/core re-entry and persistence of the fixed
storage, but does not identify the reset trigger or root cause.

This diagnostic line is now stopped. Do not begin a fault/IRQ repair or other
functional change without a new instruction from branch 2.

## Raw evidence

Raw command output for this experiment is stored below:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-BOOT-GENERATION-PERSISTENCE-DIAGNOSTIC-20260827/`

- `build_jtag_master.log`, `build_jtag_slave.log`
- `build_info_jtag_master.txt`, `build_info_jtag_slave.txt`
- `program_master.log`, `program_slave.log`
- `read_after_program.log`, `read_after_program_settled_30000.log`
- `read_immediate.log`, `read_settled_30000.log`
- `artifact_sha256.txt`, `symbol_addresses.txt`
