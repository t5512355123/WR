# EXP-WRPC-STEP4-BOOT-MODE-MASTER-ISOLATION-20260827

## Purpose

Isolate the Master boot-mode path by changing only the Master
`CONFIG_INIT_COMMAND` from the four-command sequence to:

```text
vlan off;ptp stop
```

The experiment tests whether the previous Master-side pointer offset and
boot-generation observations require the explicit `mode master` command.
This is the single experiment requested by branch 2.

## Prediction

- Master boot completes without entering Master mode.
- Master `P_AT_ENTRY_LATEST` returns to the `shell_init_cmd` value, relative
  offset 0.
- Endpoint, PTP/mailbox reads, and PHY/link probes remain readable and active.
- `BOOT_GENERATION` remains stable during a 30-second passive interval.
- Step 3 is `N/A_BY_EXPERIMENT_DESIGN` because this Master image never enters
  Master mode.

## Boundary

- Only `firmware/configs/de5a_master_defconfig` changed in source commit
  `5f7bd06`; the Slave defconfig is unchanged.
- No changes to SoftPLL, DMTD, IRQ, fault handling, RAM, PTP/PHY logic, or
  reset logic.
- Both images were freshly fully compiled and freshly programmed.
- The passive generation reader only calls `read_probe_data`; it does not use
  the Wishbone mailbox and does not hold, release, or reset the CPU.
- Other diagnostics use mailbox transactions only to read target registers;
  they do not write WR, PHY, SoftPLL, snapshot, IRQ, or reset controls.

## Reproducibility record

```text
SOURCE_COMMIT=5f7bd06ba90577f6007e76c7992ecdadbb532d14
MASTER_CONFIG_INIT_COMMAND="vlan off;ptp stop"
SLAVE_CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
MASTER_MIF_SHA256=a03d1991aa6141c7d0d160addca32d1855d4b41915943d1997fbfe7e58007992
SLAVE_MIF_SHA256=aea72734afa21ce1a7d2f6e2551dfed6106a0cfa18940b11916bb102c48de1d0
MASTER_SOF_SHA256=01ed7065a16de1e07907e6445c61f096ba6d4d513008aa5f4235a114998d20c5
SLAVE_SOF_SHA256=f2c8af82571e36ff401e5796856c7ec4c78f5521e55a39bb94aad45367b661ac
MASTER_PROGRAMMER_CHECKSUM=0x30B37E9B
SLAVE_PROGRAMMER_CHECKSUM=0x30B4455C
MASTER_JTAG_ID=0x02E660DD
SLAVE_JTAG_ID=0x02E660DD
MASTER_TIMING_CLOSED=NO
MASTER_WNS_NS=-0.383
MASTER_HNS_NS=+0.038
SLAVE_TIMING_CLOSED=NO
SLAVE_WNS_NS=-0.307
SLAVE_HNS_NS=+0.038
MASTER_COMPILE=Full Compilation was successful
SLAVE_COMPILE=Full Compilation was successful
QUARTUS_VERSION=17.0.0 Build 595 04/25/2017 SJ Standard Edition
```

The firmware symbol record gives:

```text
MASTER shell_init_cmd=0x000179d8
MASTER build_init_readcmd_p=0x0001c394
MASTER debug_boot_stage=0x0002e000
SLAVE shell_init_cmd=0x000179d8
SLAVE build_init_readcmd_p=0x0001c3a4
SLAVE debug_boot_stage=0x0002e000
```

## Observed results

### Step 1: PHY/link and clock activity

The stable post-program probe returned status words ending in `0x82EF` on
both boards. In both cases `CPU_RESET_n=1`, `link_ok=1`, `tm_link_up=1`,
`phy_ready=1`, and `si_config_done=1`. Clock-activity samples showed changing
reference, DMTD, and recovered-RX counters with `PHY_READY=1` and
`RX_LOCK_DATA=1` on both boards. `time_valid` remained 0, so this is a PHY/link
health result, not a claim of successful WR synchronization.

### Step 2: endpoint/PTP/mailbox health

The read-only boot-role timeline completed 10 samples per board. Endpoint MACs
were stable as `02:00:22:33:44:01` (Master cable) and
`02:00:22:33:44:02` (Slave cable). Endpoint and PTP counters were readable and
changing, and `PSTAT=0x00000001` remained readable.

The Master mode field was `3 (SLAVE)` in all 10 role-timeline samples and its
PTP state was `4 (LISTENING)` in all 10 samples. The Slave mode field was also
3, with the expected early transition between PTP states 9 and 4 in the
sampled window. Therefore the Master never entered mode 2 (Master).

The focused mailbox reader had transient invalid samples while the JTAG
mailbox synchronized (Master samples 1–5 and Slave samples 4–7), but it then
returned valid, updating endpoint/PTP/counter data. Those transient reader
timeouts are retained in the raw log and are not treated as target faults.

### Boot-init and parser-pointer evidence

The boot-init execution diagnostic was stable across three samples per board:

| Board | Script enter count | Command index | Mode-master call count | PTP state |
|---|---:|---:|---:|---:|
| Master | 1 | 2 | 0 | 4 (LISTENING) |
| Slave | 1 | 4 | 0 | 9 then 6 then 4 |

The Master command index 2 and zero Master-mode call count match the shortened
two-command image. The Slave command index 4 matches its unchanged four-command
image. The static startup-lifetime reader reported `PSTAT=0x00000001`,
`ASTAT=0x001FC000`, `VALID_MASK=0x3F`, and all six pointer checkpoints valid
with value 0 on both boards. The boot-role timeline also retained marker
`0x0000B004` throughout its samples.

### Step 4 passive generation monitor

All passive samples were valid. `CPU_RESET_n`, `wr_core_reset_n`,
`si_config_done`, and `clk_sys_625_locked` were 1 at every sample on both
boards. `P_AT_ENTRY_LATEST` stayed equal to `shell_init_cmd` (`0x000179D8`),
which is relative offset 0.

| Time (s) | Master generation | Master P_AT_ENTRY | Slave generation | Slave P_AT_ENTRY |
|---:|---:|---:|---:|---:|
| 0 | 2 | `0x000179D8` | 2 | `0x000179D8` |
| 5 | 2 | `0x000179D8` | 2 | `0x000179D8` |
| 10 | 2 | `0x000179D8` | 2 | `0x000179D8` |
| 20 | 2 | `0x000179D8` | 2 | `0x000179D8` |
| 30 | 2 | `0x000179D8` | 2 | `0x000179D8` |

## Interpretation

```text
STEP1_PHY_LINK=PASS
STEP2_ENDPOINT_PTP_MAILBOX=PASS_FOR_READ_ONLY_HEALTH
MASTER_MODE_ENTRY=NOT_OBSERVED
STEP3=N/A_BY_EXPERIMENT_DESIGN
MASTER_P_OFFSET_AT_ENTRY=0 (P_AT_ENTRY_LATEST == shell_init_cmd)
PASSIVE_BOOT_GENERATION_CHANGE=NOT_OBSERVED (Master 2->2, Slave 2->2)
NATURAL_CPU_RESTART_WITHOUT_FPGA_RECONFIG=NOT_PROVEN
MODE_MASTER_BOOT_PATH_SUSPECT=STRONGLY_SUPPORTED
ROOT_CAUSE=NOT_PROVEN
STEP4_PASS=NOT_CLAIMED
```

This isolation result strongly supports the hypothesis that the prior Master
offset behavior is associated with the explicit Master-mode boot path: removing
that command yields offset 0, no observed passive re-entry, and no Master-mode
entry. It does not prove the root cause of the original behavior, nor does it
demonstrate a successful Master/Slave WR synchronization run. Per branch 2's
instruction, stop here; do not start a fault/IRQ repair or another functional
change without a new experiment request.

## Raw evidence

Raw files are stored at:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-BOOT-MODE-MASTER-ISOLATION-20260827/`

- `build_info_jtag_master.txt` and `build_info_jtag_slave.txt`
- `firmware_master_build.log` and `firmware_slave_build.log`
- `artifact_sha256.txt`, `source_commit.txt`, and symbol address records
- `program_master.log` and `program_slave.log`
- `step1_probe.log`, `step1_probe_stable.log`, and `step1_clock_activity.log`
- `step2_wr_handshake_focused.log`
- `boot_role_timeline.log`
- `boot_init_execution_diag.log`, `boot_init_static_lifetime.log`, and
  `boot_init_sticky_trace.log`
- `passive_generation.log`
